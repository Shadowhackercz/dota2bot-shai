$ErrorActionPreference = 'Stop'
$logFile = New-TemporaryFile
$stateFile = New-TemporaryFile
$archiveDir = Join-Path $env:TEMP ([Guid]::NewGuid().ToString('N'))
$checker = "$PSScriptRoot\..\tools\Check-SHAILog.ps1"
function MustReject([scriptblock]$action) {
    $rejected = $false
    try { $null = & $action } catch { $rejected = $true }
    if (-not $rejected) { throw 'Expected recording validation to reject the fixture' }
}
try {
    Remove-Item -LiteralPath $stateFile.FullName
    $null = & $checker -Stage Prepare -StatePath $stateFile.FullName
    $state = Get-Content -LiteralPath $stateFile.FullName -Raw | ConvertFrom-Json
    'stale old log, no current marker' | Set-Content -LiteralPath $logFile.FullName
    MustReject { & $checker -Stage Console -StatePath $stateFile.FullName -LogPath $logFile.FullName }
    $state.marker | Set-Content -LiteralPath $logFile.FullName
    $null = & $checker -Stage Console -StatePath $stateFile.FullName -LogPath $logFile.FullName
    MustReject { & $checker -Stage Bots -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 2 }
    $lines = @(
        '[SHAI] behavior t=0.00; team=2; player=1; hero=lion;',
        '[SHAI] behavior t=15.00; team=2; player=1; hero=lion;',
        '[SHAI] behavior t=0.00; team=3; player=6; hero=zuus;',
        '[SHAI] behavior t=15.00; team=3; player=6; hero=zuus;'
    )
    # Telemetry from before the current marker must not satisfy validation.
    @($lines) + @($state.marker) | Set-Content -LiteralPath $logFile.FullName
    MustReject { & $checker -Stage Bots -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 2 }
    @($state.marker) + $lines | Set-Content -LiteralPath $logFile.FullName
    $null = & $checker -Stage Bots -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 2
    MustReject { & $checker -Stage Bots -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 3 }
    MustReject { & $checker -Stage Archive -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 2 -ArchiveDirectory $archiveDir }
    $state.endMarker | Add-Content -LiteralPath $logFile.FullName
    $null = & $checker -Stage Archive -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 2 -ArchiveDirectory $archiveDir
    $saved = @(Get-ChildItem -LiteralPath $archiveDir -Filter '*.log')
    if ($saved.Count -ne 1 -or (Get-FileHash -LiteralPath $saved[0].FullName).Hash -ne (Get-FileHash -LiteralPath $logFile.FullName).Hash) { throw 'Archived bytes differ from the recording' }
    '[SHAI] behavior t=1.00; team=3; player=6; hero=zuus;' | Add-Content -LiteralPath $logFile.FullName
    MustReject { & $checker -Stage Bots -StatePath $stateFile.FullName -LogPath $logFile.FullName -ExpectedBots 2 }
    Write-Output 'PASS: unique marker, post-marker repeated telemetry, bot count, end marker, exact archive bytes and game reset'
} finally {
    Remove-Item -LiteralPath $logFile.FullName -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stateFile.FullName -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $archiveDir) {
        foreach ($file in Get-ChildItem -LiteralPath $archiveDir -File) { Remove-Item -LiteralPath $file.FullName }
        Remove-Item -LiteralPath $archiveDir
    }
}
