[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$KrkrPatchRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = Split-Path $PSScriptRoot -Parent
$repoRoot = Split-Path (Split-Path $sourceRoot -Parent) -Parent
$lock = Get-Content -LiteralPath (Join-Path $repoRoot 'third-party.lock.json') -Raw | ConvertFrom-Json
$patchPath = Join-Path $sourceRoot 'patches\KrkrPatch-DetourRestoreAfterWith.patch'
$manifestRoot = [IO.Path]::GetFullPath($KrkrPatchRoot)
$targetPaths = @(
    'KrkrPatch/dllmain.cpp'
    'KrkrPatchLoader/KrkrPatchLoader.cpp'
)
$expectedPatchedBlobs = @{
    'KrkrPatch/dllmain.cpp' = 'a532bffe3f707d57f4125727d6367fea267007f4'
    'KrkrPatchLoader/KrkrPatchLoader.cpp' = '7b97c421b670b8659bd930359710272e41f141a3'
}

if (-not (Test-Path -LiteralPath (Join-Path $manifestRoot '.git') -PathType Container)) {
    throw "KrkrPatch repository not found: $manifestRoot"
}
if (-not (Test-Path -LiteralPath $patchPath -PathType Leaf)) {
    throw "Compatibility patch not found: $patchPath"
}

$actualCommit = (& git -C $manifestRoot rev-parse HEAD | Out-String).Trim()
$actualTree = (& git -C $manifestRoot rev-parse 'HEAD^{tree}' | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -cne [string]$lock.krkrPatch.commit -or $actualTree -cne [string]$lock.krkrPatch.tree) {
    throw "Unexpected KrkrPatch source revision: $actualCommit"
}

$modifiedFiles = @(& git -C $manifestRoot diff --name-only)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect KrkrPatch source modifications.'
}

$alreadyApplied = $false
if ($modifiedFiles.Count -gt 0) {
    $unexpectedFiles = @($modifiedFiles | Where-Object { $_ -cnotin $targetPaths })
    $missingFiles = @($targetPaths | Where-Object { $_ -cnotin $modifiedFiles })
    if ($unexpectedFiles.Count -gt 0 -or $missingFiles.Count -gt 0) {
        throw "Unexpected existing KrkrPatch modifications: $($modifiedFiles -join ', ')"
    }
    & git -C $manifestRoot apply --unidiff-zero --reverse --check --whitespace=error-all $patchPath
    $alreadyApplied = $LASTEXITCODE -eq 0
    if (-not $alreadyApplied) {
        throw 'Existing KrkrPatch modification does not match the compatibility patch.'
    }
}

if (-not $alreadyApplied) {
    & git -C $manifestRoot apply --unidiff-zero --check --whitespace=error-all $patchPath
    if ($LASTEXITCODE -ne 0) {
        throw "KrkrPatch compatibility patch check failed with exit code $LASTEXITCODE."
    }
    & git -C $manifestRoot apply --unidiff-zero --whitespace=error-all $patchPath
    if ($LASTEXITCODE -ne 0) {
        throw "KrkrPatch compatibility patch failed with exit code $LASTEXITCODE."
    }
}

& git -C $manifestRoot diff --check
if ($LASTEXITCODE -ne 0) {
    throw 'KrkrPatch compatibility patch introduced invalid whitespace.'
}

$modifiedFiles = @(& git -C $manifestRoot diff --name-only)
$unexpectedFiles = @($modifiedFiles | Where-Object { $_ -cnotin $targetPaths })
$missingFiles = @($targetPaths | Where-Object { $_ -cnotin $modifiedFiles })
if ($LASTEXITCODE -ne 0 -or $unexpectedFiles.Count -gt 0 -or $missingFiles.Count -gt 0) {
    throw "Unexpected patched KrkrPatch files: $($modifiedFiles -join ', ')"
}

foreach ($targetPath in $targetPaths) {
    $patchedBlob = (& git -C $manifestRoot hash-object --path $targetPath $targetPath | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $patchedBlob -cne $expectedPatchedBlobs[$targetPath]) {
        throw "Unexpected patched KrkrPatch source hash for ${targetPath}: $patchedBlob"
    }
}

$source = Get-Content -LiteralPath (Join-Path $manifestRoot 'KrkrPatch/dllmain.cpp') -Raw
$restoreIndex = $source.IndexOf('DetourRestoreAfterWith();', [StringComparison]::Ordinal)
$startupIndex = $source.IndexOf('OnStartup();', [StringComparison]::Ordinal)
if ($restoreIndex -lt 0 -or $startupIndex -lt 0 -or $restoreIndex -gt $startupIndex) {
    throw 'DetourRestoreAfterWith is not applied before KrkrPatch startup.'
}

$loaderSource = Get-Content -LiteralPath (Join-Path $manifestRoot 'KrkrPatchLoader/KrkrPatchLoader.cpp') -Raw
$appIdIndex = $loaderSource.IndexOf('SetEnvironmentVariableW(L"SteamAppId"', [StringComparison]::Ordinal)
$gameIdIndex = $loaderSource.IndexOf('SetEnvironmentVariableW(L"SteamGameId"', [StringComparison]::Ordinal)
$createProcessIndex = $loaderSource.IndexOf('DetourCreateProcessWithDllsW(', [StringComparison]::Ordinal)
if ($appIdIndex -lt 0 -or $gameIdIndex -lt 0 -or $createProcessIndex -lt 0 -or $appIdIndex -gt $createProcessIndex -or $gameIdIndex -gt $createProcessIndex) {
    throw 'Steam application environment is not configured before game launch.'
}

[pscustomobject]@{
    KrkrPatchRoot = $manifestRoot
    BaseCommit = $actualCommit
    ModifiedFiles = $targetPaths
    AlreadyApplied = $alreadyApplied
}
