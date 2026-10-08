param(
    [ValidateSet('Prepare', 'Console', 'Bots', 'Archive')][string]$Stage = 'Console',
    [string]$LogPath = 'C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\console.log',
    [ValidateRange(1, 10)][int]$ExpectedBots = 9,
    [string]$StatePath = (Join-Path (Split-Path -Parent $PSScriptRoot) '.tools\shai-log-check.json'),
    [string]$ArchiveDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\logs')
)
$ErrorActionPreference = 'Stop'
if ($Stage -eq 'Prepare') {
    if (Test-Path -LiteralPath $StatePath) {
        $oldState = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        Write-Warning "Preparing a new check replaces the previous marker ($($oldState.marker)). Archive the previous match before restarting Dota."
    }
    $id = [Guid]::NewGuid().ToString('N')
    $state = [pscustomobject]@{ marker = "SHAI_LOG_START_$id"; endMarker = "SHAI_LOG_END_$id"; createdUtc = [DateTime]::UtcNow.ToString('o') }
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $StatePath) -Force
    $state | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Write-Output "Before the match, enter in Dota console: echo $($state.marker)"
    Write-Output "After the match, before closing Dota: echo $($state.endMarker)"
    Write-Output 'Then run -Stage Console, and -Stage Bots after the lobby has started. No recording has been verified yet.'
    return
}
if (-not (Test-Path -LiteralPath $StatePath)) { throw 'No marker prepared. First run Check-SHAILog.ps1 -Stage Prepare.' }
$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) { throw "Log does not exist: $LogPath. Check -con_logfile in Steam launch options and restart Dota. Do not start a long test." }
# The game can keep the file open; opening with sharing also allows buffered writes to continue.
$stream = [IO.File]::Open($LogPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
try {
    $reader = New-Object IO.StreamReader($stream)
    try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
} finally { $stream.Dispose() }
$markerIndex = $content.IndexOf([string]$state.marker, [StringComparison]::Ordinal)
if ($markerIndex -lt 0) { throw 'Current unique marker is absent. A stale log is not proof of recording. Check buffering with a short run/clean exit; do not start a long test.' }
$current = $content.Substring($markerIndex)
Write-Output "Current console marker verified in: $LogPath"
if ($Stage -eq 'Console') {
    Write-Output 'Console output is being saved. Bot telemetry is not verified yet; run -Stage Bots after starting a short lobby.'
    return
}
$bots = @{}
foreach ($line in ($current -split '\r?\n')) {
    if ($line -notmatch '\[SHAI\] behavior t=(-?[0-9.]+); team=([0-9]+); player=([0-9]+); hero=([^;]+);') { continue }
    $time = [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
    $key = "$($Matches[2])/$($Matches[3])/$($Matches[4])"
    if (-not $bots.ContainsKey($key)) { $bots[$key] = @{ count = 0; first = $time; last = $time; maxGap = 0.0 } }
    $bot = $bots[$key]
    if ($time -lt $bot.last) { throw 'Game time reset inside this recording. Prepare a separate marker for each match.' }
    $bot.maxGap = [Math]::Max($bot.maxGap, $time - $bot.last)
    $bot.last = $time
    $bot.count++
}
$regular = @($bots.Keys | Where-Object { $bots[$_].count -ge 2 -and $bots[$_].last -gt $bots[$_].first })
if ($regular.Count -lt $ExpectedBots) {
    throw "Only $($regular.Count)/$ExpectedBots bots have repeated telemetry after the current marker. Wait at least 15 seconds in the short lobby and verify again. Check BehaviorTrace and Lua errors; do not treat this as a complete recording."
}
Write-Output "Repeated bot telemetry verified: $($regular.Count) bots."
foreach ($key in ($bots.Keys | Sort-Object)) {
    $bot = $bots[$key]
    Write-Output "$key : records=$($bot.count), first=$($bot.first), last=$($bot.last), maxGap=$($bot.maxGap)s"
    if ($bot.maxGap -gt 30) { Write-Warning "$key has a gap over 30 game seconds. Investigate callbacks, pauses/death and missing output before declaring complete match coverage." }
    if ($bot.first -gt 20) { Write-Warning "$key telemetry starts after 0:20. Early game coverage may be missing." }
}
Write-Output 'Coverage describes observed samples; it does not prove that every internal decision was logged.'
if ($Stage -eq 'Archive') {
    $endIndex = $current.IndexOf([string]$state.endMarker, [StringComparison]::Ordinal)
    if ($endIndex -lt 0) { throw 'End marker missing. Enter the prepared end echo after the match, close Dota normally to flush writes, and retry before restarting it.' }
    if ($endIndex -lt $current.LastIndexOf('[SHAI] behavior ', [StringComparison]::Ordinal)) { throw 'Telemetry appears after the end marker. Emit the end marker after leaving the match and closing its callbacks.' }
    $null = New-Item -ItemType Directory -Path $ArchiveDirectory -Force
    $destination = Join-Path $ArchiveDirectory ("shai-{0}-{1}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), ([Guid]::NewGuid().ToString('N').Substring(0,8)))
    # Preserve the exact source bytes; the unique destination must not overwrite an earlier recording.
    $inputStream = [IO.File]::Open($LogPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        $outputStream = [IO.File]::Open($destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
    } finally { $inputStream.Dispose() }
    Write-Output "Archived recording: $destination"
}
