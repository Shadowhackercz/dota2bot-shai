$ErrorActionPreference = 'Stop'
$fixture = New-TemporaryFile
try {
    @(
        'unrelated engine output',
        '[SHAI] behavior t=0.00; team=2; player=3; hero=zuus; mode=LANING; hp=1.00; target=none; rapid=0; reversals=0',
        '[SHAI] behavior t=1.00; team=2; player=3; hero=zuus; mode=RETREAT; hp=0.40; target=none; rapid=2; reversals=1',
        '[SHAI] behavior t=10.00; team=2; player=3; hero=zuus; mode=RETREAT; hp=0.50; target=none; rapid=2; reversals=1',
        '[SHAI] defense t=1500; hero=warlock; reason=group-pressure; target=ogre; members=4; damage=1600; excluded=centaur:low-hp; utility=1; healthy=3; regenBudget=500; effectiveHP=2500',
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
        '[SHAI] invis t=1518; hero=witch_doctor; reason=safe-home-tp',
        '[SHAI] wraith t=1519; hero=skeleton_king; reason=stun; target=pudge; remaining=3',
        '[SHAI] farm-spell t=1520; hero=lion; reason=lion-spike; hits=2; damage=255; reserve=380',
        '[SHAI] rune-share t=1521; hero=lion; reason=bottle-approach; target=zeus; rune=0; until=1524',
        '[SHAI] ping-intent t=1522; hero=lion; reason=double-ping; player=3',
        '[SHAI] travel t=1523; hero=zeus; reason=route-detour; purpose=wisdom; x=100; y=200',
        '[SHAI] escape t=1524; hero=centaur; reason=escape-stampede; enemy=pudge',
        '[SHAI] defense-cast t=1525; hero=witch_doctor; reason=issued; spell=witch_doctor_maledict; target=pudge; members=2; purpose=engage; until=1525.5',
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
        $output -notmatch '\[escape\].*reason=jump-issued; terrain=true; x=100; y=200' -or
        $output -notmatch '\[invis\].*reason=safe-home-tp' -or
        $output -notmatch '\[wraith\].*reason=stun; target=pudge; remaining=3' -or
        $output -notmatch '\[rune-share\].*reason=bottle-approach; target=zeus; rune=0; until=1524' -or
        $output -notmatch '\[ping-intent\].*reason=double-ping; player=3' -or
        $output -notmatch '\[travel\].*reason=route-detour; purpose=wisdom; x=100; y=200' -or
        $output -notmatch '\[escape\].*reason=escape-stampede; enemy=pudge' -or
        $output -notmatch '\[defense-cast\].*reason=issued; spell=witch_doctor_maledict; target=pudge; members=2; purpose=engage; until=1525.5' -or
        $output -notmatch '\[defense\].*utility=1; healthy=3; regenBudget=500; effectiveHP=2500' -or
        $output -notmatch '\[farm-spell\].*reason=lion-spike; hits=2; damage=255; reserve=380') { throw "Analyzer lost decision reasons, objective readiness, combat budgets, memory snapshots or runtime failures: $output" }
    '[SHAI] defense t=1526; hero=axe; reason=group-ongoing; fighting=3; recentHitters=2' | Add-Content -LiteralPath $fixture.FullName
    $ongoingOutput = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($ongoingOutput -notmatch 'reason=group-ongoing; fighting=3; recentHitters=2') { throw 'Analyzer lost ongoing defense evidence' }
    '[SHAI] wisdom t=1527; hero=axe; reason=no-progress-deferred; x=-7948; y=768' | Add-Content -LiteralPath $fixture.FullName
    $wisdomOutput = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($wisdomOutput -notmatch '\[wisdom\].*reason=no-progress-deferred') { throw 'Analyzer lost Wisdom progress diagnostic' }
    '[SHAI] recovery t=1528; hero=skeleton_king; reason=return-to-fountain' | Add-Content -LiteralPath $fixture.FullName
    $recoveryOutput = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($recoveryOutput -notmatch '\[recovery\].*reason=return-to-fountain') { throw 'Analyzer lost fountain recovery diagnostic' }
    '[SHAI] escape-item t=1529; hero=lion; reason=blocked-self-save; item=item_glimmer_cape; physical=50; magical=400' | Add-Content -LiteralPath $fixture.FullName
    $saveOutput = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($saveOutput -notmatch '\[escape-item\].*item=item_glimmer_cape; physical=50; magical=400') { throw 'Analyzer lost emergency item diagnostic' }
    '[SHAI] escape-item t=1530; hero=lion; reason=ghost-home-tp; channel=3; incoming=40' | Add-Content -LiteralPath $fixture.FullName
    $comboOutput = & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName | Out-String -Width 200
    if ($comboOutput -notmatch '\[escape-item\].*reason=ghost-home-tp; channel=3; incoming=40') { throw 'Analyzer lost Ghost TP diagnostic' }
    'unrelated engine output' | Set-Content -LiteralPath $fixture.FullName
    $rejected = $false
    try { & "$PSScriptRoot\..\tools\Analyze-SHAI.ps1" -LogPath $fixture.FullName } catch { $rejected = $true }
    if (-not $rejected) { throw 'Missing telemetry must not appear to be a clean game' }
    Write-Output 'PASS: behavior intervals, defense/travel reasons, native/helper errors and missing telemetry rejection'
} finally {
    Remove-Item -LiteralPath $fixture.FullName
}
