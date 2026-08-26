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
$targetPath = 'KrkrPatch/dllmain.cpp'
$expectedPatchedBlob = 'a532bffe3f707d57f4125727d6367fea267007f4'

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
    if ($modifiedFiles.Count -ne 1 -or $modifiedFiles[0] -cne $targetPath) {
        throw "Unexpected existing KrkrPatch modifications: $($modifiedFiles -join ', ')"
    }
    & git -C $manifestRoot apply --reverse --check --whitespace=error-all $patchPath
    $alreadyApplied = $LASTEXITCODE -eq 0
    if (-not $alreadyApplied) {
        throw 'Existing KrkrPatch modification does not match the compatibility patch.'
    }
}

if (-not $alreadyApplied) {
    & git -C $manifestRoot apply --check --whitespace=error-all $patchPath
    if ($LASTEXITCODE -ne 0) {
        throw "KrkrPatch compatibility patch check failed with exit code $LASTEXITCODE."
    }
    & git -C $manifestRoot apply --whitespace=error-all $patchPath
    if ($LASTEXITCODE -ne 0) {
        throw "KrkrPatch compatibility patch failed with exit code $LASTEXITCODE."
    }
}

& git -C $manifestRoot diff --check
if ($LASTEXITCODE -ne 0) {
    throw 'KrkrPatch compatibility patch introduced invalid whitespace.'
}

$modifiedFiles = @(& git -C $manifestRoot diff --name-only)
if ($LASTEXITCODE -ne 0 -or $modifiedFiles.Count -ne 1 -or $modifiedFiles[0] -cne $targetPath) {
    throw "Unexpected patched KrkrPatch files: $($modifiedFiles -join ', ')"
}

$patchedBlob = (& git -C $manifestRoot hash-object --path $targetPath $targetPath | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $patchedBlob -cne $expectedPatchedBlob) {
    throw "Unexpected patched KrkrPatch source hash: $patchedBlob"
}

$source = Get-Content -LiteralPath (Join-Path $manifestRoot $targetPath) -Raw
$restoreIndex = $source.IndexOf('DetourRestoreAfterWith();', [StringComparison]::Ordinal)
$startupIndex = $source.IndexOf('OnStartup();', [StringComparison]::Ordinal)
if ($restoreIndex -lt 0 -or $startupIndex -lt 0 -or $restoreIndex -gt $startupIndex) {
    throw 'DetourRestoreAfterWith is not applied before KrkrPatch startup.'
}

[pscustomobject]@{
    KrkrPatchRoot = $manifestRoot
    BaseCommit = $actualCommit
    ModifiedFile = $targetPath
    AlreadyApplied = $alreadyApplied
}
