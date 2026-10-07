param(
    [string]$DotaPath = 'C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta'
)
$ErrorActionPreference = 'Stop'
$repoPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourcePath = [IO.Path]::GetFullPath((Join-Path $repoPath 'bots'))
$dotaRoot = (Resolve-Path -LiteralPath $DotaPath).Path
$scriptsPath = [IO.Path]::GetFullPath((Join-Path $dotaRoot 'game\dota\scripts\vscripts'))
$destinationPath = [IO.Path]::GetFullPath((Join-Path $scriptsPath 'bots'))

if (-not (Test-Path -LiteralPath (Join-Path $dotaRoot 'game\bin\win64\dota2.exe'))) {
    throw "Dota 2 executable not found under $dotaRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'hero_selection.lua'))) {
    throw "SHAI source not found under $sourcePath"
}
if ([IO.Path]::GetDirectoryName($destinationPath) -ne $scriptsPath -or
    [IO.Path]::GetFileName($destinationPath) -ne 'bots' -or
    -not $scriptsPath.StartsWith($dotaRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must be the bots directory inside the chosen Dota installation'
}

$existing = Get-Item -LiteralPath $destinationPath -Force -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.LinkType -eq 'Junction' -and
        [string]$existing.Target -eq $sourcePath) {
        Write-Output "SHAI already linked: $destinationPath -> $sourcePath"
        return
    }
    $backupPath = Join-Path $scriptsPath ('bots_before_shai_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($backupPath)) -ne $scriptsPath) {
        throw 'Backup must stay in the same Dota scripts directory'
    }
    # Preserve existing scripts or link; never delete their contents.
    Move-Item -LiteralPath $destinationPath -Destination $backupPath
    Write-Output "Previous bots preserved at: $backupPath"
}

try {
    New-Item -ItemType Junction -Path $destinationPath -Target $sourcePath | Out-Null
} catch {
    if ($backupPath -and -not (Get-Item -LiteralPath $destinationPath -Force -ErrorAction SilentlyContinue)) {
        Move-Item -LiteralPath $backupPath -Destination $destinationPath
    }
    throw
}
$installed = Get-Item -LiteralPath $destinationPath -Force
if ($installed.LinkType -ne 'Junction' -or [string]$installed.Target -ne $sourcePath) {
    throw 'SHAI junction verification failed'
}
Write-Output "SHAI linked: $destinationPath -> $sourcePath"
Write-Output 'Use Custom Lobby / Local Host / All Pick / Local Dev Script for BOTH teams.'
Write-Output 'Bots should have names ending in .SHAI. Start a new match after source edits.'
if (Test-Path -LiteralPath (Join-Path $scriptsPath 'game\Customize\general.lua')) {
    Write-Warning 'Existing game/Customize/general.lua still overrides general settings. SHAI hero pool remains in the repo bots/Customize/shai.lua.'
}
