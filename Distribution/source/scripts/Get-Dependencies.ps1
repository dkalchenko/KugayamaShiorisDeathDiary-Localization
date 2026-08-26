[CmdletBinding()]
param(
    [ValidateSet('All', 'MsgTool', 'KrkrPatch', 'Vcpkg')]
    [string[]]$Components = @('MsgTool'),

    [string]$DestinationPath,

    [string]$GitHubEnvironmentPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path (Split-Path $sourceRoot -Parent) -Parent
$lockPath = Join-Path $repoRoot 'third-party.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $cacheRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($cacheRoot)) {
        $cacheRoot = [IO.Path]::GetTempPath()
    }
    $DestinationPath = Join-Path $cacheRoot 'KugayamaShioriLocalization\dependencies'
}

$destinationRoot = [IO.Path]::GetFullPath($DestinationPath)
[IO.Directory]::CreateDirectory($destinationRoot) | Out-Null

function Invoke-Native {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList
    )

    & $FilePath @ArgumentList | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

function Assert-SafeChildPath {
    param([string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $relativePath = [IO.Path]::GetRelativePath($destinationRoot, $fullPath)
    if (
        $relativePath -eq '.' -or
        [IO.Path]::IsPathRooted($relativePath) -or
        $relativePath -eq '..' -or
        $relativePath.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
    ) {
        throw "Unsafe dependency path: $fullPath"
    }
    return $fullPath
}

function Reset-DependencyDirectory {
    param([string]$Path)

    $fullPath = Assert-SafeChildPath $Path
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }
    [IO.Directory]::CreateDirectory($fullPath) | Out-Null
    return $fullPath
}

function Test-FileHash {
    param(
        [string]$Path,
        [string]$ExpectedHash,
        [ValidateSet('SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash
    return $actualHash.Equals($ExpectedHash, [StringComparison]::OrdinalIgnoreCase)
}

function Get-VerifiedDownload {
    param(
        [string]$Url,
        [string]$ExpectedHash,
        [ValidateSet('SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )

    $downloadsRoot = Join-Path $destinationRoot 'downloads'
    [IO.Directory]::CreateDirectory($downloadsRoot) | Out-Null
    $fileName = [IO.Path]::GetFileName(([Uri]$Url).AbsolutePath)
    $downloadPath = Assert-SafeChildPath (Join-Path $downloadsRoot $fileName)
    if (Test-FileHash $downloadPath $ExpectedHash $Algorithm) {
        return $downloadPath
    }

    $partialPath = Assert-SafeChildPath "$downloadPath.partial"
    if (Test-Path -LiteralPath $partialPath) {
        Remove-Item -LiteralPath $partialPath -Force
    }
    Invoke-WebRequest -Uri $Url -OutFile $partialPath
    if (-not (Test-FileHash $partialPath $ExpectedHash $Algorithm)) {
        Remove-Item -LiteralPath $partialPath -Force
        throw "Downloaded file checksum mismatch: $Url"
    }
    Move-Item -LiteralPath $partialPath -Destination $downloadPath -Force
    return $downloadPath
}

function Get-PinnedRepository {
    param(
        [string]$Name,
        [object]$Configuration
    )

    $repositoryPath = Assert-SafeChildPath (Join-Path $destinationRoot "$Name-$($Configuration.commit)")
    $valid = $false
    if (Test-Path -LiteralPath (Join-Path $repositoryPath '.git') -PathType Container) {
        $head = (& git -C $repositoryPath rev-parse HEAD 2>$null | Out-String).Trim()
        $tree = (& git -C $repositoryPath rev-parse 'HEAD^{tree}' 2>$null | Out-String).Trim()
        $valid = $LASTEXITCODE -eq 0 -and $head -ceq [string]$Configuration.commit -and $tree -ceq [string]$Configuration.tree
    }
    if ($valid) {
        return $repositoryPath
    }

    Reset-DependencyDirectory $repositoryPath | Out-Null
    Invoke-Native git @('init', '--quiet', $repositoryPath)
    Invoke-Native git @('-C', $repositoryPath, 'remote', 'add', 'origin', [string]$Configuration.repository)
    Invoke-Native git @('-C', $repositoryPath, 'fetch', '--depth', '1', '--no-tags', 'origin', [string]$Configuration.commit)
    Invoke-Native git @('-C', $repositoryPath, 'checkout', '--quiet', '--detach', 'FETCH_HEAD')

    $head = (& git -C $repositoryPath rev-parse HEAD | Out-String).Trim()
    $tree = (& git -C $repositoryPath rev-parse 'HEAD^{tree}' | Out-String).Trim()
    if ($head -cne [string]$Configuration.commit -or $tree -cne [string]$Configuration.tree) {
        throw "$Name source revision verification failed."
    }
    return $repositoryPath
}

function Add-GitHubEnvironmentValue {
    param(
        [string]$Name,
        [string]$Value
    )

    if (-not [string]::IsNullOrWhiteSpace($GitHubEnvironmentPath)) {
        Add-Content -LiteralPath $GitHubEnvironmentPath -Value "$Name=$Value" -Encoding utf8
    }
}

function Get-MsgTool {
    $configuration = $lock.msgTool
    $toolDirectory = Assert-SafeChildPath (Join-Path $destinationRoot "msg-tool-$($configuration.version)")
    $executablePath = Join-Path $toolDirectory ([string]$configuration.executableName)
    $valid = Test-FileHash $executablePath ([string]$configuration.executableSha256)
    if ($valid) {
        $version = (& $executablePath --version | Out-String).Trim()
        $valid = $LASTEXITCODE -eq 0 -and $version -ceq "msg_tool $($configuration.version)"
    }

    if (-not $valid) {
        Reset-DependencyDirectory $toolDirectory | Out-Null
        $archivePath = Get-VerifiedDownload ([string]$configuration.windowsX64Url) ([string]$configuration.archiveSha256)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
        try {
            $entry = $archive.GetEntry([string]$configuration.executableName)
            if ($null -eq $entry) {
                throw "msg-tool archive does not contain $($configuration.executableName)."
            }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $executablePath, $true)
        } finally {
            $archive.Dispose()
        }
        if (-not (Test-FileHash $executablePath ([string]$configuration.executableSha256))) {
            throw 'Extracted msg-tool executable checksum mismatch.'
        }
        Unblock-File -LiteralPath $executablePath -ErrorAction SilentlyContinue
        $version = (& $executablePath --version | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $version -cne "msg_tool $($configuration.version)") {
            throw "Unexpected msg-tool version: $version"
        }
    }
    return $executablePath
}

function Get-PkgConfig {
    $configuration = $lock.pkgConfig
    $toolDirectory = Assert-SafeChildPath (Join-Path $destinationRoot "pkg-config-$($configuration.version)")
    $executablePath = [IO.Path]::GetFullPath((Join-Path $toolDirectory ([string]$configuration.executableRelativePath)))
    $runtimePath = [IO.Path]::GetFullPath((Join-Path $toolDirectory ([string]$configuration.runtimeRelativePath)))
    foreach ($path in @($executablePath, $runtimePath)) {
        $relativePath = [IO.Path]::GetRelativePath($toolDirectory, $path)
        if ([IO.Path]::IsPathRooted($relativePath) -or $relativePath -eq '..' -or $relativePath.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)) {
            throw 'Invalid pkg-config tool path.'
        }
    }

    $valid = (Test-FileHash $executablePath ([string]$configuration.executableSha256)) -and
        (Test-FileHash $runtimePath ([string]$configuration.runtimeSha256))
    if ($valid) {
        $version = (& $executablePath --version | Out-String).Trim()
        $valid = $LASTEXITCODE -eq 0 -and $version -ceq [string]$configuration.version
    }

    if (-not $valid) {
        Reset-DependencyDirectory $toolDirectory | Out-Null
        $tar = (Get-Command 'tar.exe' -CommandType Application -ErrorAction Stop).Source
        foreach ($archive in $configuration.archives) {
            $archivePath = Get-VerifiedDownload ([string]$archive.url) ([string]$archive.sha512) 'SHA512'
            Invoke-Native $tar @('-xf', $archivePath, '-C', $toolDirectory)
        }
        if (-not (Test-FileHash $executablePath ([string]$configuration.executableSha256))) {
            throw 'Extracted pkg-config executable checksum mismatch.'
        }
        if (-not (Test-FileHash $runtimePath ([string]$configuration.runtimeSha256))) {
            throw 'Extracted pkg-config runtime checksum mismatch.'
        }
        Unblock-File -LiteralPath @($executablePath, $runtimePath) -ErrorAction SilentlyContinue
        $version = (& $executablePath --version | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $version -cne [string]$configuration.version) {
            throw "Unexpected pkg-config version: $version"
        }
    }
    return $executablePath
}

$requestedComponents = if ($Components -contains 'All') {
    @('MsgTool', 'KrkrPatch', 'Vcpkg')
} else {
    @($Components | Select-Object -Unique)
}

$result = [ordered]@{}
if ($requestedComponents -contains 'MsgTool') {
    $result.MsgToolPath = Get-MsgTool
    Add-GitHubEnvironmentValue 'MSG_TOOL_PATH' $result.MsgToolPath
}
if ($requestedComponents -contains 'KrkrPatch') {
    $result.KrkrPatchRoot = Get-PinnedRepository 'KrkrPatch' $lock.krkrPatch
    Add-GitHubEnvironmentValue 'KRKRPATCH_ROOT' $result.KrkrPatchRoot
}
if ($requestedComponents -contains 'Vcpkg') {
    $result.VcpkgRoot = Get-PinnedRepository 'vcpkg' $lock.vcpkg
    $result.PkgConfigPath = Get-PkgConfig
    $env:PKG_CONFIG = $result.PkgConfigPath
    Add-GitHubEnvironmentValue 'PKG_CONFIG' $result.PkgConfigPath
    $sevenZip = $lock.vcpkg.sevenZip
    $archiveName = [string]$sevenZip.archiveName
    if ([string]::IsNullOrWhiteSpace($archiveName) -or [IO.Path]::GetFileName($archiveName) -cne $archiveName) {
        throw 'Invalid vcpkg 7-Zip archive name.'
    }
    $sevenZipArchive = Get-VerifiedDownload ([string]$sevenZip.url) ([string]$sevenZip.sha512) 'SHA512'
    $vcpkgDownloads = Join-Path $result.VcpkgRoot 'downloads'
    [IO.Directory]::CreateDirectory($vcpkgDownloads) | Out-Null
    $sevenZipTarget = Join-Path $vcpkgDownloads $archiveName
    Copy-Item -LiteralPath $sevenZipArchive -Destination $sevenZipTarget -Force
    if (-not (Test-FileHash $sevenZipTarget ([string]$sevenZip.sha512) 'SHA512')) {
        throw 'Cached vcpkg 7-Zip archive checksum mismatch.'
    }
    $vcpkgExecutable = Join-Path $result.VcpkgRoot 'vcpkg.exe'
    if (-not (Test-Path -LiteralPath $vcpkgExecutable -PathType Leaf)) {
        Invoke-Native (Join-Path $result.VcpkgRoot 'bootstrap-vcpkg.bat') @('-disableMetrics')
    }
    Add-GitHubEnvironmentValue 'VCPKG_ROOT' $result.VcpkgRoot
}

[pscustomobject]$result
