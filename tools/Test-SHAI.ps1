$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$luaCli = Join-Path $projectRoot '.tools\lua\node_modules\.bin\fengari.cmd'
if (-not (Test-Path -LiteralPath $luaCli)) {
    throw 'Missing Fengari. Run: npm.cmd install --prefix .tools/lua --no-package-lock --ignore-scripts fengari-node-cli'
}
Push-Location $projectRoot
try {
    # Fengari has no io.open. Extract the actual callback, with its dependencies
    # supplied by the test, instead of copying/mirroring its implementation.
    $abilitySource = Get-Content -LiteralPath 'bots/ability_item_usage_generic.lua' -Raw
    $callbackMatch = [regex]::Match($abilitySource, '(?s)(function AbilityUsageThink\(\).*?\r?\nend)\r?\n\r?\nfunction BuybackUsageThink')
    if (-not $callbackMatch.Success) { throw 'Cannot locate actual AbilityUsageThink callback' }
    $adapter = "return function(bot,J,TeamGank,BehaviorTrace,SHAI,Customize,BotBuild,RefreshBotHandle,bInstallChatCallbackDone,botName,ObjectiveCommands,RoshanCommands,X,CombatFinish,Defense,Travel,ThreatMemory,RoshanSafety,UseGlyph)`nUseGlyph = UseGlyph or function() end`nCombatFinish = CombatFinish or {TryAction=function() return false end, IsCommitting=function() return false end}`nDefense = Defense or {GuardAbilities=function() return false end}`nTravel = Travel or {ThinkFade=function() return false end}`nThreatMemory = ThreatMemory or {Observe=function() end}`nRoshanSafety = RoshanSafety or {GuardActions=function() return false end}`nlocal Wraith=require('bots/FunLib/shai_wraith_form')`nlocal Invisible=require('bots/FunLib/shai_invisible_escape')`nlocal Runtime=require('bots/FunLib/shai_runtime')`n" + $callbackMatch.Groups[1].Value + "`nreturn AbilityUsageThink`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-ability-callback.lua'), $adapter, [Text.UTF8Encoding]::new($false))
    $itemMatch = [regex]::Match($abilitySource, '(?s)(function ItemUsageThink\(\).*?\r?\nend)\r?\n\r?\nfunction AbilityUsageThink')
    if (-not $itemMatch.Success) { throw 'Cannot locate actual ItemUsageThink callback' }
    $itemAdapter = "return function(bot,J,Customize,RefreshBotHandle,CombatFinish,ItemUsageComplement,botName,Travel,RoshanSafety)`nTravel = Travel or {ThinkFade=function() return false end,RecheckTeleport=function() return false end}`nRoshanSafety = RoshanSafety or {GuardActions=function() return false end}`nlocal Wraith=require('bots/FunLib/shai_wraith_form')`nlocal Invisible=require('bots/FunLib/shai_invisible_escape')`nlocal Runtime=require('bots/FunLib/shai_runtime')`n" + $itemMatch.Groups[1].Value + "`nreturn ItemUsageThink`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-item-callback.lua'), $itemAdapter, [Text.UTF8Encoding]::new($false))
    $helperSource = Get-Content -LiteralPath 'bots/FunLib/jmz_func.lua' -Raw
    $locationBodies = foreach ($name in @('GetAlliesNearLoc', 'GetEnemiesNearLoc')) {
        $locationMatch = [regex]::Match($helperSource, "(?s)function J\.$name\([^)]*\).*?\r?\nend")
        if (-not $locationMatch.Success) { throw "Cannot locate actual J.$name helper" }
        $locationMatch.Value
    }
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-location-helpers.lua'),
        "return function(J,Runtime)`n" + ($locationBodies -join "`n") + "`nend`n", [Text.UTF8Encoding]::new($false))
    $intentBodies = foreach ($name in @('IsRetreating', 'IsGoingOnSomeone')) {
        $intentMatch = [regex]::Match($helperSource, "(?s)function J\.$name\([^)]*\).*?\r?\nend")
        if (-not $intentMatch.Success) { throw "Cannot locate actual J.$name helper" }
        $intentMatch.Value
    }
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-intent-helpers.lua'),
        "return function(J)`n" + ($intentBodies -join "`n") + "`nend`n", [Text.UTF8Encoding]::new($false))
    $guardBodies = foreach ($name in @('CanNotUseAction', 'CanNotUseAbility')) {
        $guardMatch = [regex]::Match($helperSource, "(?s)function J\.$name\([^)]*\).*?\r?\nend")
        if (-not $guardMatch.Success) { throw "Cannot locate actual J.$name guard" }
        $guardMatch.Value
    }
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-action-guards.lua'),
        "return function(J)`n" + ($guardBodies -join "`n") + "`nend`n", [Text.UTF8Encoding]::new($false))
    $farmSource = Get-Content -LiteralPath 'bots/mode_farm_generic.lua' -Raw
    $repickMatch = [regex]::Match($farmSource, '(?s)\tbot\._farm_repick_at = bot\._farm_repick_at or 0.*?(?=\tif preferedCamp ~= nil then)')
    if (-not $repickMatch.Success) { throw 'Cannot locate actual farm camp selection' }
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-camp-selection.lua'),
        "return function(bot,J,FarmSafety,preferedCamp,availableCamp)`n" + $repickMatch.Value + "`nreturn preferedCamp`nend`n", [Text.UTF8Encoding]::new($false))
    $buybackMatch = [regex]::Match($abilitySource, '(?s)function BuybackUsageThink\(\).*?\r?\nend')
    if (-not $buybackMatch.Success) { throw 'Cannot locate actual buyback callback' }
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-buyback-callback.lua'),
        "return function(bot,RefreshBotHandle,UseGlyph,BuybackUsageComplement)`n" + $buybackMatch.Value + "`nreturn BuybackUsageThink`nend`n", [Text.UTF8Encoding]::new($false))
    $idleMatch = [regex]::Match($helperSource, '(?s)function J.CheckBotIdleState\(\).*?\r?\nend')
    if (-not $idleMatch.Success) { throw 'Cannot locate actual idle watchdog' }
    $idleAdapter = "return function(J,Runtime)`nlocal botIdleStateTracker={}`nlocal botIdelStateTimeThreshold,deltaIdleDistance=3,100`n" + $idleMatch.Value + "`nreturn J.CheckBotIdleState`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-idle-helper.lua'), $idleAdapter, [Text.UTF8Encoding]::new($false))
    $castMatch = [regex]::Match($abilitySource, '(?s)function X.SetUseItem\([^)]*\).*?\r?\nend')
    if (-not $castMatch.Success) { throw 'Cannot locate actual item dispatcher' }
    $castAdapter = "return function(bot,J,Travel,Runtime)`nlocal X={}`n" + $castMatch.Value + "`nreturn X.SetUseItem`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-item-cast.lua'), $castAdapter, [Text.UTF8Encoding]::new($false))
    $pollenMatch = [regex]::Match($abilitySource, '(?s)X\.ConsiderItemDesire\["item_jidi_pollen_bag"\] = function\( hItem \).*?\r?\nend(?=\r?\n\r?\nX\.ConsiderItemDesire)')
    if (-not $pollenMatch.Success) { throw 'Cannot locate actual Pollen Bag consideration' }
    $pollenAdapter = "return function(bot,J)`nlocal X={ConsiderItemDesire={}}`n" + $pollenMatch.Value + "`nreturn X.ConsiderItemDesire['item_jidi_pollen_bag']`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-pollen-helper.lua'), $pollenAdapter, [Text.UTF8Encoding]::new($false))
    $glyphMatch = [regex]::Match($abilitySource, '(?s)local function UseGlyph\(\).*?\r?\nend(?=\r?\n\r?\nfunction ItemUsageThink)')
    if (-not $glyphMatch.Success) { throw 'Cannot locate actual glyph callback' }
    $glyphAdapter = "return function(bot,team,Glyph,Runtime)`n" + $glyphMatch.Value + "`nreturn UseGlyph`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-glyph-callback.lua'), $glyphAdapter, [Text.UTF8Encoding]::new($false))
    $objectiveHelperBodies = foreach ($name in @('IsDoingRoshan', 'IsDoingTormentor')) {
        $helperMatch = [regex]::Match($helperSource, "(?s)function J\.$name\([^)]*\).*?\r?\nend")
        if (-not $helperMatch.Success) { throw "Cannot locate actual J.$name helper" }
        $helperMatch.Value
    }
    $helperAdapter = "return function(J,ObjectiveCommands)`n" + ($objectiveHelperBodies -join "`n") + "`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-objective-helpers.lua'), $helperAdapter, [Text.UTF8Encoding]::new($false))
    foreach ($testFile in @('tests/shai-runtime-api.test.lua', 'tests/shai-camp.test.lua', 'tests/shai-objective-integration.test.lua', 'tests/shai-selection.test.lua', 'tests/shai-roshan.test.lua',
        'tests/shai-combat.test.lua', 'tests/shai-lion-farm.test.lua', 'tests/shai-centaur-escape.test.lua', 'tests/shai-tactics.test.lua', 'tests/shai-runes.test.lua', 'tests/shai-route.test.lua', 'tests/shai-pings.test.lua', 'tests/shai-escape.test.lua', 'tests/shai-special-states.test.lua',
        'tests/shai-stability.test.lua', 'tests/shai-objectives.test.lua', 'tests/shai-tombstone.test.lua', 'tests/shai-trace.test.lua',
        'tests/shai-roshan-chat.test.lua', 'tests/shai-safety.test.lua', 'tests/shai-memory.test.lua', 'tests/shai-gank.test.lua', 'tests/shai-budget.test.lua', 'tests/shai-glyph.test.lua', 'tests/shai-objective-chat.test.lua', 'tests/shai-finish.test.lua', 'tests/shai-defense.test.lua', 'tests/shai-travel.test.lua')) {
        # Fresh VM per test; explicit exit because Fengari otherwise swallows errors.
        & $luaCli -e "local ok, err = pcall(dofile, '$testFile'); if not ok then print(err); os.exit(1) end"
        if ($LASTEXITCODE -ne 0) { throw "Failed: $testFile" }
    }
    & "$projectRoot\tests\shai-analysis.test.ps1"
    & "$projectRoot\tests\shai-log-check.test.ps1"
} finally {
    Pop-Location
}
