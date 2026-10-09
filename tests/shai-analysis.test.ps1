$ErrorActionPreference = 'Stop'
$fixture = New-TemporaryFile
try {
    @(
        'unrelated engine output',
        '[SHAI] behavior t=0.00; team=2; player=3; hero=zuus; mode=LANING; hp=1.00; target=none; rapid=0; reversals=0',
        '[SHAI] behavior t=1.00; team=2; player=3; hero=zuus; mode=RETREAT; hp=0.40; target=none; rapid=2; reversals=1',
        '[SHAI] behavior t=10.00; team=2; player=3; hero=zuus; mode=RETREAT; hp=0.50; target=none; rapid=2; reversals=1',
        '[SHAI] defense t=1500; hero=warlock; reason=group-pressure; target=ogre; members=4; damage=1600; excluded=centaur:low-hp',
        '[SHAI] travel t=1510; hero=centaur; reason=unsafe-tp-destination',
        '[SHAI] runtime t=1512; source=item.cast; error=missing location',
        'Script Runtime Error: error in error handling',
        'GetUnitToLocationDistance parameter 2: expected vectorws but got void.'
    ) | Set-Content -LiteralPath $fixture.FullName
    $output = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($output -notmatch 'RETREAT' -or $output -notmatch 'ReversalDelta' -or $output -notmatch '2/3/zuus') {
        throw 'Analyzer did not expose bot summary and suspicious interval'
    }
    if ($output -notmatch 'group-pressure' -or $output -notmatch 'unsafe-tp-destination' -or
        $output -notmatch 'Reported script exceptions: 1; invalid-location warnings: 1; helper failures: 1' -or $output -notmatch 'source=item.cast' -or
        $output -notmatch 'excluded=centaur:low-hp') { throw 'Analyzer lost decision reasons or runtime failures' }
    'unrelated engine output' | Set-Content -LiteralPath $fixture.FullName
    $rejected = $false
    try { & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName } catch { $rejected = $true }
    if (-not $rejected) { throw 'Missing telemetry must not appear to be a clean game' }
    Write-Output 'PASS: behavior intervals, defense/travel reasons, native/helper errors and missing telemetry rejection'
} finally {
    Remove-Item -LiteralPath $fixture.FullName
}
