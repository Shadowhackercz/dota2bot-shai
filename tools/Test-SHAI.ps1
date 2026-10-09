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
    $adapter = "return function(bot,J,TeamGank,BehaviorTrace,SHAI,Customize,BotBuild,RefreshBotHandle,bInstallChatCallbackDone,botName,ObjectiveCommands,RoshanCommands,X,CombatFinish,Defense,Travel)`nCombatFinish = CombatFinish or {TryAction=function() return false end, IsCommitting=function() return false end}`nDefense = Defense or {GuardAbilities=function() return false end}`nTravel = Travel or {ThinkFade=function() return false end}`nlocal Runtime=require('bots/FunLib/shai_runtime')`n" + $callbackMatch.Groups[1].Value + "`nreturn AbilityUsageThink`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-ability-callback.lua'), $adapter, [Text.UTF8Encoding]::new($false))
    $itemMatch = [regex]::Match($abilitySource, '(?s)(function ItemUsageThink\(\).*?\r?\nend)\r?\n\r?\nfunction AbilityUsageThink')
    if (-not $itemMatch.Success) { throw 'Cannot locate actual ItemUsageThink callback' }
    $itemAdapter = "return function(bot,J,Customize,RefreshBotHandle,CombatFinish,ItemUsageComplement,botName,Travel)`nTravel = Travel or {ThinkFade=function() return false end,RecheckTeleport=function() return false end}`nlocal Runtime=require('bots/FunLib/shai_runtime')`n" + $itemMatch.Groups[1].Value + "`nreturn ItemUsageThink`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-item-callback.lua'), $itemAdapter, [Text.UTF8Encoding]::new($false))
    $helperSource = Get-Content -LiteralPath 'bots/FunLib/jmz_func.lua' -Raw
    $idleMatch = [regex]::Match($helperSource, '(?s)function J.CheckBotIdleState\(\).*?\r?\nend')
    if (-not $idleMatch.Success) { throw 'Cannot locate actual idle watchdog' }
    $idleAdapter = "return function(J,Runtime)`nlocal botIdleStateTracker={}`nlocal botIdelStateTimeThreshold,deltaIdleDistance=3,100`n" + $idleMatch.Value + "`nreturn J.CheckBotIdleState`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-idle-helper.lua'), $idleAdapter, [Text.UTF8Encoding]::new($false))
    $castMatch = [regex]::Match($abilitySource, '(?s)function X.SetUseItem\([^)]*\).*?\r?\nend')
    if (-not $castMatch.Success) { throw 'Cannot locate actual item dispatcher' }
    $castAdapter = "return function(bot,J,Travel,Runtime)`nlocal X={}`n" + $castMatch.Value + "`nreturn X.SetUseItem`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-item-cast.lua'), $castAdapter, [Text.UTF8Encoding]::new($false))
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
    foreach ($testFile in @('tests/shai-selection.test.lua', 'tests/shai-roshan.test.lua',
        'tests/shai-combat.test.lua', 'tests/shai-tactics.test.lua', 'tests/shai-runes.test.lua',
        'tests/shai-stability.test.lua', 'tests/shai-objectives.test.lua', 'tests/shai-tombstone.test.lua', 'tests/shai-trace.test.lua',
        'tests/shai-roshan-chat.test.lua', 'tests/shai-safety.test.lua', 'tests/shai-gank.test.lua', 'tests/shai-budget.test.lua', 'tests/shai-glyph.test.lua', 'tests/shai-objective-chat.test.lua', 'tests/shai-finish.test.lua', 'tests/shai-defense.test.lua', 'tests/shai-travel.test.lua')) {
        # Fresh VM per test; explicit exit because Fengari otherwise swallows errors.
        & $luaCli -e "local ok, err = pcall(dofile, '$testFile'); if not ok then print(err); os.exit(1) end"
        if ($LASTEXITCODE -ne 0) { throw "Failed: $testFile" }
    }
    & "$projectRoot\tests\shai-analysis.test.ps1"
    & "$projectRoot\tests\shai-log-check.test.ps1"
} finally {
    Pop-Location
}
