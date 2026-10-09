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
    $adapter = "return function(bot,J,TeamGank,BehaviorTrace,SHAI,Customize,BotBuild,RefreshBotHandle,bInstallChatCallbackDone,botName,ObjectiveCommands,RoshanCommands,X)`n" + $callbackMatch.Groups[1].Value + "`nreturn AbilityUsageThink`nend`n"
    [IO.File]::WriteAllText((Join-Path $projectRoot '.tools/lua/shai-ability-callback.lua'), $adapter, [Text.UTF8Encoding]::new($false))
    $helperSource = Get-Content -LiteralPath 'bots/FunLib/jmz_func.lua' -Raw
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
        'tests/shai-roshan-chat.test.lua', 'tests/shai-safety.test.lua', 'tests/shai-gank.test.lua', 'tests/shai-objective-chat.test.lua')) {
        # Fresh VM per test; explicit exit because Fengari otherwise swallows errors.
        & $luaCli -e "local ok, err = pcall(dofile, '$testFile'); if not ok then print(err); os.exit(1) end"
        if ($LASTEXITCODE -ne 0) { throw "Failed: $testFile" }
    }
    & "$projectRoot\tests\shai-analysis.test.ps1"
    & "$projectRoot\tests\shai-log-check.test.ps1"
} finally {
    Pop-Location
}
