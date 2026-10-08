param([Parameter(Mandatory)][string]$LogPath)
$ErrorActionPreference = 'Stop'
$previous = @{}
$events = @()
foreach ($line in Get-Content -LiteralPath $LogPath) {
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
