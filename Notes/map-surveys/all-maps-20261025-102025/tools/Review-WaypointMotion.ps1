param(
    [Parameter(Mandatory=$true)][string]$LogPath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
# Offline review only. BOT_TRACE tx/ty/tz describe the selected enemy, not
# necessarily the navigation goal (embark routes lead to the bot's pet Titan).
$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
function Fields([string]$line) {
    $bag = @{}
    foreach ($m in [regex]::Matches($line, '(?:^|\s)([a-z_]+)=([^\s]+)')) {
        $bag[$m.Groups[1].Value] = $m.Groups[2].Value
    }
    return $bag
}
function Num($s) { return [double]::Parse([string]$s,$culture) }
function Stamp([string]$line) {
    if ($line -match '^\[(\d{4}-\d{2}-\d{2})\] \[(\d{2}:\d{2}:\d{2})\]') {
        return [datetime]::ParseExact("$($Matches[1]) $($Matches[2])",'yyyy-MM-dd HH:mm:ss',$culture)
    }
    return $null
}
$n = '([-+\d.eE]+)'
$vector = 'Vector3 \{ x: '+$n+', y: '+$n+', z: '+$n+' \}'
$pattern = 'BOT_MOTION slot=(\d+) mode=(\d+) hp=(-?\d+) pos='+$vector+
    ' horizontal_delta='+$n+'.*?next='+$vector+' route_nodes=(\d+)'
$players = @{}; $traces = @{}; $frame = $null
$rows = [Collections.Generic.List[object]]::new()
$motionLines = 0; $unmatched = 0
$hasSurvey = $false
foreach($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $LogPath))){
    if($line.Contains('MAP_SURVEY_BEGIN ')){$hasSurvey=$true;break}
}
$measuring = -not $hasSurvey
foreach ($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $LogPath))) {
    if ($line.Contains('MAP_SURVEY_BEGIN ')) {
        $measuring = $true
    } elseif ($line.Contains('MAP_SURVEY_RESULT ') -or $line.Contains('MAP_SURVEY_DONE ')) {
        $measuring = $false
    } elseif ($line.Contains('BOT_FRAME ')) {
        $frame = Fields $line
    } elseif ($line.Contains('BOT_PLAYER ')) {
        $p = Fields $line; $p.stamp = Stamp $line
        $players["$($p.epoch)|$($p.slot)"] = $p
    } elseif ($line.Contains('BOT_TRACE ')) {
        $p = Fields $line; $p.stamp = Stamp $line
        $traces["$($p.epoch)|$($p.slot)"] = $p
    } elseif ($line.Contains('BOT_MOTION slot=')) {
        if(-not $measuring){continue}
        $motionLines++
        if ($line -notmatch $pattern) { $unmatched++; continue }
        $m = $Matches.Clone(); $stamp = Stamp $line
        $slot = [int]$m[1]; $key = "$($frame.epoch)|$slot"
        $p = $players[$key]; $trace = $traces[$key]
        $x=Num $m[4]; $y=Num $m[5]; $z=Num $m[6]
        $nx=Num $m[8]; $ny=Num $m[9]; $nz=Num $m[10]
        $xy=[Math]::Sqrt(($nx-$x)*($nx-$x)+($ny-$y)*($ny-$y))
        $age=if($p -and $stamp -and $p.stamp){($stamp-$p.stamp).TotalSeconds}else{999}
        $traceAge=if($trace -and $stamp -and $trace.stamp){($stamp-$trace.stamp).TotalSeconds}else{999}
        $positionGap=if($p){[Math]::Sqrt([Math]::Pow($x-(Num $p.x),2)+[Math]::Pow($y-(Num $p.y),2)+[Math]::Pow($z-(Num $p.z),2))}else{99999}
        $contextOk=$p -and $trace -and $age -ge 0 -and $age -le 3 -and $traceAge -ge 0 -and $traceAge -le 3 -and $positionGap -le 250
        $pilot=$contextOk -and $p.bot -eq '1' -and $p.alive -eq '1' -and $p.titan -eq '0' -and [int]$m[3] -gt 0 -and [int]$m[3] -le 100
        $state=if($contextOk){$trace.state}else{'unmatched'}
        $lowProgress=(Num $m[7]) -lt 50
        $rows.Add([pscustomobject][ordered]@{
            map=$frame.map; epoch=$frame.epoch; t_approx=$frame.t; wall_time=$stamp
            slot=$slot; hp=[int]$m[3]; state=$state; pilot_context=[int]$pilot
            context_age_seconds=$age; context_position_gap=[Math]::Round($positionGap,2)
            x=$x; y=$y; z=$z; nx=$nx; ny=$ny; nz=$nz
            waypoint_horizontal=[Math]::Round($xy,2); waypoint_height=[Math]::Round($nz-$z,2)
            horizontal_delta_10s=Num $m[7]; low_progress=[int]$lowProgress
            route_nodes=[int]$m[11]
            near_xy_other_height=[int]($xy -le 45 -and [Math]::Abs($nz-$z) -gt 45)
            grid=('{0},{1},{2}' -f ([Math]::Round($x/128)*128),([Math]::Round($y/128)*128),([Math]::Round($z/64)*64))
        })
    }
}
if ($unmatched -gt 0) { throw "$unmatched of $motionLines BOT_MOTION lines failed parsing" }
if ($rows.Count -eq 0) { throw 'No BOT_MOTION samples found' }
$pilots=@($rows | Where-Object pilot_context -eq 1)
$navigation=@($pilots | Where-Object state -in @('pursue','embark','recover'))
$low=@($navigation | Where-Object low_progress -eq 1)
$summary=[ordered]@{
    log=(Resolve-Path -LiteralPath $LogPath).Path; motion_lines=$motionLines; parsed=$rows.Count
    scope=if($hasSurvey){'MAP_SURVEY_BEGIN through result or end of log; warmup excluded'}else{'Whole log; no survey measurement markers'}
    pilot_context_samples=$pilots.Count; navigation_samples=$navigation.Count
    low_progress_navigation_samples=$low.Count
    low_progress_states=@($low|Group-Object state|ForEach-Object{[pscustomobject]@{state=$_.Name;samples=$_.Count}})
    low_progress_waypoint_height_over_180=@($low|Where-Object{[Math]::Abs($_.waypoint_height)-gt180}).Count
    low_progress_near_xy_other_height=@($low|Where-Object near_xy_other_height -eq 1).Count
    top_low_progress_areas=@($low|Group-Object map,grid|Sort-Object Count -Descending|Select-Object -First 8|ForEach-Object{
        $g=@($_.Group); $heights=@($g.waypoint_height|Sort-Object)
        [pscustomobject]@{area=$_.Name;samples=$g.Count;slots=@($g.slot|Sort-Object -Unique);states=@($g.state|Sort-Object -Unique);waypoint_height_median=$heights[[int]($heights.Count/2)];near_xy_other_height=@($g|Where-Object near_xy_other_height -eq 1).Count}
    })
    limits='Motion sampled about every 10 seconds. Context comes from preceding 2-second player/trace samples (max 3 wall seconds and 250 units); game time is approximate. Low progress is endpoint XY displacement below 50, not proof of continuous immobility. A next waypoint can be stale when path following is inactive; these records do not capture waypoint consumption, selected polygons, collision traces or active hull mapping. No causal diagnosis follows from height alone.'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$rows.ToArray()|Export-Csv (Join-Path $OutputDirectory 'waypoint-motion.csv') -NoTypeInformation
$summary|ConvertTo-Json -Depth 7|Set-Content (Join-Path $OutputDirectory 'summary.json')
$summary|ConvertTo-Json -Depth 7
