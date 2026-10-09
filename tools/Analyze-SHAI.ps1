param([Parameter(Mandatory)][string]$LogPath)
$ErrorActionPreference = 'Stop'
$previous = @{}
$events = @()
$decisions = @()
$reportedErrors = @()
$scriptExceptions = 0
$invalidLocations = 0
$helperFailures = 0
foreach ($line in Get-Content -LiteralPath $LogPath) {
    if ($line -match 'Script Runtime Error') { $scriptExceptions++ }
    if ($line -match 'GetUnitToLocationDistance.*(got void|expected vector)') { $invalidLocations++ }
    if ($line -match '\[SHAI\] runtime ') { $helperFailures++ }
    if ($line -match 'Script Runtime Error|GetUnitToLocationDistance.*(got void|expected vector)|\[SHAI\] runtime ') {
        $reportedErrors += $line
    }
    if ($line -match '\[SHAI\] (farm-spell|invis|wraith|escape|defense-wave|defense|gank|gank-member|gank-reinforce|finish|safety|travel|glyph|runtime|idle-recovery|tormentor|roshan-safety) (.*)') {
        $kind, $detail = $Matches[1], $Matches[2]
        $decisionFields = @{}
        foreach ($field in $detail -split '; ') {
            $pair = $field -split '=', 2
            if ($pair.Count -eq 2) { $decisionFields[$pair[0]] = $pair[1] }
        }
        $decisions += [pscustomobject]@{Kind=$kind; Reason=$decisionFields.reason;
            Time=$decisionFields.t; Hero=$decisionFields.hero; Target=$decisionFields.target;
            Source=$decisionFields.source; Detail=$detail}
    }
    if ($line -notmatch '\[SHAI\] behavior (.*)') { continue }
    $fields = @{}
    foreach ($field in $Matches[1] -split '; ') {
        $pair = $field -split '=', 2
        if ($pair.Count -eq 2) { $fields[$pair[0]] = $pair[1] }
    }
    $key = "$($fields.team)/$($fields.player)/$($fields.hero)"
    $rapid = [int]$fields.rapid
    $reversals = [int]$fields.reversals
    $old = $previous[$key]
    if ($null -ne $old -and ($rapid -gt $old.rapid -or $reversals -gt $old.reversals)) {
        $events += [pscustomobject]@{Time=$fields.t; Hero=$fields.hero; Team=$fields.team;
            Mode=$fields.mode; HP=$fields.hp; Target=$fields.target;
            RapidDelta=[Math]::Max(0, $rapid-$old.rapid);
            ReversalDelta=[Math]::Max(0, $reversals-$old.reversals)}
    }
    $previous[$key] = @{rapid=$rapid; reversals=$reversals}
}
if ($previous.Count -eq 0) { throw 'No [SHAI] behavior records found. Enable BehaviorTrace, use -con_logfile in Steam launch options, and verify recording before a new match.' }
Write-Output 'Latest observed cumulative counters per bot (suspicion indicators, not error scores):'
$summaries = foreach ($key in ($previous.Keys | Sort-Object)) {
    [pscustomobject]@{Bot=$key; Rapid=$previous[$key].rapid; Reversals=$previous[$key].reversals}
}
$summaries | Format-Table -AutoSize
Write-Output 'Intervals to inspect in replay (time in seconds; output is throttled):'
$events | Format-Table -AutoSize
Write-Output 'Decision reason counts (throttled diagnostics, not total decisions):'
$decisions | Group-Object -Property Kind,Reason | Sort-Object -Property Count -Descending |
    Select-Object Name,Count | Format-Table -AutoSize
Write-Output "Reported script exceptions: $scriptExceptions; invalid-location warnings: $invalidLocations; helper failures: $helperFailures (engine may suppress duplicates)."
$reportedErrors | Select-Object -First 12 | Write-Output
Write-Output 'Recent combat, objective readiness, remembered threats, glyph, travel and helper error details (up to 20 records):'
$decisions | Where-Object { ($_.Kind -in @('farm-spell','invis','wraith','escape','defense-wave','defense','gank','glyph','travel','runtime','tormentor','roshan-safety')) -or ($_.Kind -eq 'safety' -and $_.Reason -eq 'remembered-farm-threat') } |
    Select-Object -Last 20 | ForEach-Object { "[$($_.Kind)] $($_.Detail)" }
