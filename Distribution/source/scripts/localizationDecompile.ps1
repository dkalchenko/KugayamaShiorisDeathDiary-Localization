[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$InputPath = 'C:\Program Files (x86)\Steam\steamapps\common\久我山栞の死様手帖\patch.xp3',

    [Parameter(Position = 1)]
    [string]$OutputPath,

    [string]$MsgToolPath,

    [ValidateRange(0, 4)]
    [int]$LanguageIndex = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = Split-Path $PSScriptRoot -Parent

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $sourceRoot 'generated\english'
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

function Write-FileList {
    param(
        [object]$Manifest,
        [string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("$($Manifest.archivePathHash):")
    foreach ($scenario in $Manifest.scenarios) {
        $lines.Add("$($scenario.hash):$($scenario.fileName)")
    }
    $lines.Add("$($Manifest.uiText.hash):$($Manifest.uiText.fileName)")
    [IO.File]::WriteAllLines($Path, $lines, [Text.UTF8Encoding]::new($false))
}

$tool = Resolve-MsgTool $MsgToolPath
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$output = [IO.Path]::GetFullPath($OutputPath)
$manifestPath = Join-Path $sourceRoot 'scenarios.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ([IO.Path]::GetExtension($resolvedInput) -ieq '.xp3') {
    [IO.Directory]::CreateDirectory($output) | Out-Null
    $originalDirectory = Join-Path $sourceRoot 'generated\original'
    if (Test-Path -LiteralPath $originalDirectory) {
        Remove-Item -LiteralPath $originalDirectory -Recurse -Force
    }
    [IO.Directory]::CreateDirectory($originalDirectory) | Out-Null
    $fileList = Join-Path $sourceRoot 'generated\filelist.lst'
    Write-FileList $manifest $fileList

    Invoke-MsgTool $tool @(
        'unpack',
        '--xp3-game-title', $manifest.msgToolGameTitle,
        '--xp3-file-list-path', $fileList,
        '--xp3-cxdec-file-hash', 'with-name',
        '--xp3-cxdec-path-hash', 'name-only',
        '-x', '1',
        '-X', '2',
        $resolvedInput,
        $originalDirectory
    )

    foreach ($scenario in $manifest.scenarios) {
        $scenarioInput = Join-Path $originalDirectory $scenario.fileName
        $scenarioOutput = Join-Path $output $scenario.jsonFile
        if (-not (Test-Path -LiteralPath $scenarioInput -PathType Leaf)) {
            throw "Scenario was not extracted: $($scenario.fileName)"
        }
        Invoke-MsgTool $tool @(
            'export',
            '-t', 'kirikiri-scn',
            '-T', 'json',
            '--kirikiri-language-index', $LanguageIndex.ToString(),
            '-x', '1',
            '-X', '2',
            $scenarioInput,
            $scenarioOutput
        )
    }

    $uiTextInput = Join-Path $originalDirectory $manifest.uiText.fileName
    $uiTextOutput = Join-Path $output $manifest.uiText.fileName
    if (-not (Test-Path -LiteralPath $uiTextInput -PathType Leaf)) {
        throw "UI text was not extracted: $($manifest.uiText.fileName)"
    }
    [IO.File]::Copy($uiTextInput, $uiTextOutput, $true)

    Write-Host "Exported $($manifest.scenarios.Count) scenarios and UI text to $output"
    return
}

$singleOutput = $output
if ([IO.Path]::GetExtension($output) -ine '.json') {
    [IO.Directory]::CreateDirectory($output) | Out-Null
    $singleOutput = Join-Path $output ((Split-Path $resolvedInput -Leaf) + '.json')
} else {
    [IO.Directory]::CreateDirectory((Split-Path $output -Parent)) | Out-Null
}

Invoke-MsgTool $tool @(
    'export',
    '-t', 'kirikiri-scn',
    '-T', 'json',
    '--kirikiri-language-index', $LanguageIndex.ToString(),
    '-x', '1',
    '-X', '2',
    $resolvedInput,
    $singleOutput
)

Write-Host "Exported $resolvedInput to $singleOutput"
