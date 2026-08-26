[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath,

    [string]$GameArchivePath = 'C:\Program Files (x86)\Steam\steamapps\common\久我山栞の死様手帖\patch.xp3',

    [string]$MsgToolPath,

    [ValidateRange(0, 4)]
    [int]$LanguageIndex = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = Split-Path $PSScriptRoot -Parent

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path $sourceRoot 'localization\ru'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $sourceRoot 'generated\localization.xp3'
}

function Resolve-MsgTool {
    param([string]$RequestedPath)

    $candidates = @(
        $RequestedPath,
        $env:MSG_TOOL_PATH,
        'msg_tool.exe'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    $dependency = & (Join-Path $PSScriptRoot 'Get-Dependencies.ps1') -Components MsgTool
    if ($null -eq $dependency -or [string]::IsNullOrWhiteSpace([string]$dependency.MsgToolPath)) {
        throw 'msg_tool.exe could not be acquired. Pass -MsgToolPath or set MSG_TOOL_PATH.'
    }
    return [string]$dependency.MsgToolPath
}

function Invoke-MsgTool {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "msg-tool failed with exit code $LASTEXITCODE."
    }
}

function Assert-NamesUnchanged {
    param(
        [string]$EnglishPath,
        [string]$TranslationPath
    )

    [array]$english = Get-Content -LiteralPath $EnglishPath -Raw | ConvertFrom-Json
    [array]$translation = Get-Content -LiteralPath $TranslationPath -Raw | ConvertFrom-Json
    if (@($english).Count -ne @($translation).Count) {
        throw "Entry count differs: $TranslationPath"
    }

    for ($index = 0; $index -lt @($english).Count; $index++) {
        $englishProperty = $english[$index].PSObject.Properties['name']
        $translationProperty = $translation[$index].PSObject.Properties['name']
        $englishName = if ($null -eq $englishProperty) { '' } else { [string]$englishProperty.Value }
        $translationName = if ($null -eq $translationProperty) { '' } else { [string]$translationProperty.Value }
        if ($englishName -cne $translationName) {
            throw "Name changed at entry $index in $TranslationPath"
        }
    }
}

function Assert-TranslationRoundTrip {
    param(
        [string]$TranslationPath,
        [string]$VerificationPath
    )

    [array]$translation = Get-Content -LiteralPath $TranslationPath -Raw | ConvertFrom-Json
    [array]$verification = Get-Content -LiteralPath $VerificationPath -Raw | ConvertFrom-Json
    if (@($translation).Count -ne @($verification).Count) {
        throw "Round-trip entry count differs: $VerificationPath"
    }

    for ($index = 0; $index -lt @($translation).Count; $index++) {
        $translationNameProperty = $translation[$index].PSObject.Properties['name']
        $verificationNameProperty = $verification[$index].PSObject.Properties['name']
        $translationName = if ($null -eq $translationNameProperty) { '' } else { [string]$translationNameProperty.Value }
        $verificationName = if ($null -eq $verificationNameProperty) { '' } else { [string]$verificationNameProperty.Value }
        if ($translationName -cne $verificationName) {
            throw "Round-trip name differs at entry $index in $VerificationPath"
        }
        if ([string]$translation[$index].message -cne [string]$verification[$index].message) {
            throw "Round-trip message differs at entry $index in $VerificationPath"
        }
    }
}

$tool = Resolve-MsgTool $MsgToolPath
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$output = [IO.Path]::GetFullPath($OutputPath)
$archive = (Resolve-Path -LiteralPath $GameArchivePath).Path
$manifest = Get-Content -LiteralPath (Join-Path $sourceRoot 'scenarios.json') -Raw | ConvertFrom-Json
if ($manifest.sourceArchiveSha256) {
    $actualArchiveHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualArchiveHash -cne [string]$manifest.sourceArchiveSha256) {
        throw "Unsupported game archive: expected SHA-256 $($manifest.sourceArchiveSha256), found $actualArchiveHash."
    }
}
$generatedRoot = Join-Path $sourceRoot 'generated'
$englishDirectory = Join-Path $generatedRoot 'english'
$originalDirectory = Join-Path $generatedRoot 'original'
$patchedDirectory = Join-Path $generatedRoot 'patched'
[IO.Directory]::CreateDirectory($originalDirectory) | Out-Null

& (Join-Path $PSScriptRoot 'localizationDecompile.ps1') -InputPath $archive -OutputPath $englishDirectory -MsgToolPath $tool -LanguageIndex 1

if (Test-Path -LiteralPath $patchedDirectory) {
    Remove-Item -LiteralPath $patchedDirectory -Recurse -Force
}
[IO.Directory]::CreateDirectory($patchedDirectory) | Out-Null

[array]$selected = if (Test-Path -LiteralPath $resolvedInput -PathType Leaf) {
    $inputFileName = Split-Path $resolvedInput -Leaf
    @($manifest.scenarios | Where-Object { $_.jsonFile -ceq $inputFileName })
} else {
    @($manifest.scenarios)
}

if (@($selected).Count -eq 0) {
    throw "No manifest entry matches $resolvedInput"
}

foreach ($scenario in $selected) {
    $translationPath = if (Test-Path -LiteralPath $resolvedInput -PathType Leaf) { $resolvedInput } else { Join-Path $resolvedInput $scenario.jsonFile }
    $englishPath = Join-Path $englishDirectory $scenario.jsonFile
    $originalPath = Join-Path $originalDirectory $scenario.fileName
    $patchedPath = Join-Path $patchedDirectory $scenario.fileName

    if (-not (Test-Path -LiteralPath $translationPath -PathType Leaf)) {
        throw "Missing translation: $translationPath"
    }

    Assert-NamesUnchanged $englishPath $translationPath
    Invoke-MsgTool $tool @(
        'import',
        '-t', 'kirikiri-scn',
        '-T', 'json',
        '--kirikiri-language-index', $LanguageIndex.ToString(),
        '-x', '1',
        '-X', '2',
        $originalPath,
        $translationPath,
        $patchedPath
    )
}

[IO.Directory]::CreateDirectory((Split-Path $output -Parent)) | Out-Null
Invoke-MsgTool $tool @(
    'pack',
    '-t', 'kirikiri-xp3',
    '--xp3-segmenter', 'none',
    '-x', '1',
    '-X', '2',
    $patchedDirectory,
    $output
)

$verificationDirectory = Join-Path $generatedRoot 'verify'
if (Test-Path -LiteralPath $verificationDirectory) {
    Remove-Item -LiteralPath $verificationDirectory -Recurse -Force
}
Invoke-MsgTool $tool @(
    'unpack',
    '-t', 'kirikiri-xp3',
    '-x', '1',
    '-X', '2',
    $output,
    $verificationDirectory
)

$verifiedCount = @(Get-ChildItem -LiteralPath $verificationDirectory -File -Filter '*.scn').Count
if ($verifiedCount -ne @($selected).Count) {
    throw "Archive verification failed: expected $(@($selected).Count) SCNs, found $verifiedCount."
}

$verificationJsonDirectory = Join-Path $generatedRoot 'verify-json'
if (Test-Path -LiteralPath $verificationJsonDirectory) {
    Remove-Item -LiteralPath $verificationJsonDirectory -Recurse -Force
}
[IO.Directory]::CreateDirectory($verificationJsonDirectory) | Out-Null

foreach ($scenario in $selected) {
    $translationPath = if (Test-Path -LiteralPath $resolvedInput -PathType Leaf) { $resolvedInput } else { Join-Path $resolvedInput $scenario.jsonFile }
    $verificationScnPath = Join-Path $verificationDirectory $scenario.fileName
    $verificationJsonPath = Join-Path $verificationJsonDirectory $scenario.jsonFile
    Invoke-MsgTool $tool @(
        'export',
        '-t', 'kirikiri-scn',
        '-T', 'json',
        '--kirikiri-language-index', $LanguageIndex.ToString(),
        '-x', '1',
        '-X', '2',
        $verificationScnPath,
        $verificationJsonPath
    )
    Assert-TranslationRoundTrip $translationPath $verificationJsonPath
}

Write-Host "Compiled $verifiedCount scenarios into $output"
