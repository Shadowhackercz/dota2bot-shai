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
        '[SHAI] glyph t=1511; hero=lion; reason=imminent-loss; fall=3.00; dps=500; attackers=3',
        '[SHAI] gank t=1511; leader=lion; phase=declined; reason=insufficient-damage; attacks=500; spells=200; summons=0; mana=100',
        '[SHAI] safety t=1511; hero=zeus; reason=remembered-farm-threat; enemy=silencer; age=2.00; confidence=0.80; radius=1140; x=600; y=0',
        '[SHAI] runtime t=1512; source=item.cast; error=missing location',
        '[SHAI] tormentor t=1513; team=2; hero=lion; reason=damage; desire=0; damageIndex=200; coreLevel=15; supportLevel=12; availability=unknown',
        '[SHAI] roshan-safety t=1514; team=2; hero=lion; reason=outside-pit',
        '[SHAI] glyph t=1515; team=2; hero=lion; reason=ready-no-siege; cooldown=0',
        '[SHAI] tormentor t=1515; team=2; hero=lion; reason=callback-check; source=team-roam',
        '[SHAI] defense-wave t=1516; hero=zeus; reason=zuus_arc_lightning; target=siege-creep',
        '[SHAI] escape t=1517; hero=zeus; reason=jump-issued; terrain=true; x=100; y=200',
        'Script Runtime Error: error in error handling',
        'GetUnitToLocationDistance parameter 2: expected vectorws but got void.'
    ) | Set-Content -LiteralPath $fixture.FullName
    $output = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($output -notmatch 'RETREAT' -or $output -notmatch 'ReversalDelta' -or $output -notmatch '2/3/zuus') {
        throw 'Analyzer did not expose bot summary and suspicious interval'
    }
    if ($output -notmatch 'group-pressure' -or $output -notmatch 'unsafe-tp-destination' -or
        $output -notmatch 'Reported script exceptions: 1; invalid-location warnings: 1; helper failures: 1' -or $output -notmatch 'source=item.cast' -or
        $output -notmatch 'excluded=centaur:low-hp' -or $output -notmatch 'imminent-loss' -or
        $output -notmatch 'attacks=500; spells=200; summons=0; mana=100' -or
        $output -notmatch 'age=2.00; confidence=0.80; radius=1140; x=600; y=0' -or
        $output -notmatch 'damageIndex=200; coreLevel=15; supportLevel=12; availability=unknown' -or
        $output -notmatch '\[roshan-safety\].*reason=outside-pit' -or
        $output -notmatch '\[glyph\].*reason=ready-no-siege; cooldown=0' -or
        $output -notmatch '\[tormentor\].*reason=callback-check; source=team-roam' -or
        $output -notmatch '\[defense-wave\].*reason=zuus_arc_lightning; target=siege-creep' -or
        $output -notmatch '\[escape\].*reason=jump-issued; terrain=true; x=100; y=200') { throw "Analyzer lost decision reasons, objective readiness, combat budgets, memory snapshots or runtime failures: $output" }
    'unrelated engine output' | Set-Content -LiteralPath $fixture.FullName
    $rejected = $false
    try { & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName } catch { $rejected = $true }
    if (-not $rejected) { throw 'Missing telemetry must not appear to be a clean game' }
    Write-Output 'PASS: behavior intervals, defense/travel reasons, native/helper errors and missing telemetry rejection'
} finally {
    Remove-Item -LiteralPath $fixture.FullName
}
