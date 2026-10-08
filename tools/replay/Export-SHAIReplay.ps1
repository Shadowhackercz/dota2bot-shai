param(
    [Parameter(Mandatory)][string]$ReplayPath,
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.tools\replay\export')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$runtimeRoot = Join-Path $projectRoot '.tools\replay'
$java = @(Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'jre21') -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'bin\java.exe' } | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
if (-not $java -or -not (Test-Path -LiteralPath (Join-Path $runtimeRoot 'ecj.jar'))) {
    throw 'Local Java 21/ECJ runtime missing. See tools/replay/README.md for dependency versions. The tool never uploads the replay.'
}
$jars = @(Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'lib') -Filter '*.jar')
if ($jars.Count -lt 6) { throw 'Replay parser dependencies missing; see tools/replay/README.md.' }
$classDir = Join-Path $runtimeRoot 'classes'
& $java -jar (Join-Path $runtimeRoot 'ecj.jar') -21 -cp (($jars | ForEach-Object FullName) -join ';') -d $classDir (Join-Path $PSScriptRoot 'ReadReplay.java')
if ($LASTEXITCODE -ne 0) { throw "Replay exporter compilation failed: $LASTEXITCODE" }
& $java -Xmx2g -cp "$classDir;$(Join-Path $runtimeRoot 'lib\*')" ReadReplay ([IO.Path]::GetFullPath($ReplayPath)) ([IO.Path]::GetFullPath($OutputDirectory))
if ($LASTEXITCODE -ne 0) { throw "Replay export failed: $LASTEXITCODE. Partial output is not a completed analysis." }
& node (Join-Path $PSScriptRoot 'SummarizeReplay.cjs') ([IO.Path]::GetFullPath($OutputDirectory))
if ($LASTEXITCODE -ne 0) { throw "Replay summary failed: $LASTEXITCODE" }
