$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$luaCli = Join-Path $projectRoot '.tools\lua\node_modules\.bin\fengari.cmd'
if (-not (Test-Path -LiteralPath $luaCli)) {
    throw 'Missing Fengari. Run: npm.cmd install --prefix .tools/lua --no-package-lock --ignore-scripts fengari-node-cli'
}
Push-Location $projectRoot
try {
    foreach ($testFile in @('tests/shai-selection.test.lua', 'tests/shai-roshan.test.lua',
        'tests/shai-combat.test.lua', 'tests/shai-tactics.test.lua', 'tests/shai-runes.test.lua',
        'tests/shai-stability.test.lua', 'tests/shai-objectives.test.lua', 'tests/shai-tombstone.test.lua', 'tests/shai-trace.test.lua')) {
        # Fresh VM per test; explicit exit because Fengari otherwise swallows errors.
        & $luaCli -e "local ok, err = pcall(dofile, '$testFile'); if not ok then print(err); os.exit(1) end"
        if ($LASTEXITCODE -ne 0) { throw "Failed: $testFile" }
    }
    & "$projectRoot\tests\shai-analysis.test.ps1"
} finally {
    Pop-Location
}
