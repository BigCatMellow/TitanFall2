param([string]$LogPath, [string]$OutputDirectory, [switch]$Open)
$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
if (-not $LogPath) {
    $LogPath = (Get-ChildItem "$env:USERPROFILE\northstar-crash-audit\local-test-profile\logs\nslog*.txt" |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$LogPath = (Resolve-Path -LiteralPath $LogPath).Path
if (-not $OutputDirectory) {
    $name = [IO.Path]::GetFileNameWithoutExtension($LogPath).Replace(' ', '_')
    $OutputDirectory = Join-Path (Split-Path $PSScriptRoot) "sessions\$name"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
function Number($bag, $key, $default = 0) {
    $number = 0.0
    if ($bag.ContainsKey($key) -and [double]::TryParse([string]$bag[$key],
        [Globalization.NumberStyles]::Float, $culture, [ref]$number)) { return $number }
    return $default
}
function Fields([string]$line) {
    $bag = @{}
    foreach ($match in [regex]::Matches($line, '(?:^|\s)([a-z_]+)=([^\s]+)')) {
        $bag[$match.Groups[1].Value] = $match.Groups[2].Value
    }
    return $bag
}
function Row($k) {
    [pscustomobject][ordered]@{
        epoch=[int](Number $k 'epoch'); map=[string]$k.map; t=(Number $k 't');
        slot=[int](Number $k 'slot'); id=[int](Number $k 'id'); team=[int](Number $k 'team');
        bot=[int](Number $k 'bot'); alive=[int](Number $k 'alive'); titan=[int](Number $k 'titan');
        hp=[int](Number $k 'hp'); x=(Number $k 'x'); y=(Number $k 'y'); z=(Number $k 'z');
        target=-1; visible=0; state='unknown'; tx=0.; ty=0.; tz=0.; speed=0.; yaw=0.;
        switches=0; recoveries=0; path_failures=0; path_requests=0; jumps=0; commands=0;
        yaw_travel=0.; supporters=0; nodes=0; neighbors=0; spacing=0; near_allies=0;
        failed_goal_skips=0; retreats=0; route_recovery=-1;
        stalled=0; coordination=-1; source='structured'
    }
}
$rows = [Collections.Generic.List[object]]::new()
$legacy = [Collections.Generic.List[object]]::new()
$events = [Collections.Generic.List[object]]::new()
$lookup = @{}
$frameModes = @{}
$frameRecovery = @{}
$epochMaps = @{}
$map = 'unknown'; $legacyEpoch = 0; $legacyStart = $null; $legacyActive = $false
$raw = Get-Content -LiteralPath $LogPath
foreach ($line in $raw) {
    if ($line -match 'UICodeCallback_LevelInit: (mp_[a-z0-9_]+)') { $map = $Matches[1] }
    if ($line -match 'BOT_LIFECYCLE: match playing') {
        $legacyEpoch++; $legacyStart = $null; $legacyActive = $true
    }
    if ($line -match 'HostState: ChangeLevelMP') { $legacyActive = $false }
    if ($line.Contains('BOT_FRAME ')) {
        $k = Fields $line
        $frameModes["$($k.epoch)|$($k.map)|$($k.t)"] = [int](Number $k 'coordination')
        $frameRecovery["$($k.epoch)|$($k.map)|$($k.t)"] = [int](Number $k 'route_recovery' -1)
        $epochMaps[[string]$k.epoch] = [string]$k.map
    } elseif ($line.Contains('BOT_PLAYER ')) {
        $k = Fields $line; $row = Row $k
        $rows.Add($row)
        $lookup["$($k.epoch)|$($k.map)|$($k.t)|$($k.slot)"] = $row
        $epochMaps[[string]$k.epoch] = [string]$k.map
    } elseif ($line.Contains('BOT_TRACE ')) {
        $k = Fields $line
        $row = $lookup["$($k.epoch)|$($k.map)|$($k.t)|$($k.slot)"]
        if ($null -ne $row) {
            foreach ($key in @('target','visible','tx','ty','tz','speed','yaw','switches','recoveries',
                'path_failures','path_requests','jumps','commands','yaw_travel','supporters','nodes','neighbors','spacing','failed_goal_skips','retreats')) {
                $row.$key = Number $k $key
            }
            $row.state = [string]$k.state
        }
    } elseif ($line.Contains('BOT_RECOVERY ') -or $line.Contains('BOT_DECISION ') -or $line.Contains('BOT_ROUTE ') -or $line.Contains('BOT_ESCAPE ')) {
        $k = Fields $line
        $k.kind = if ($line.Contains('BOT_RECOVERY ')) {'recovery'} elseif ($line.Contains('BOT_ROUTE ')) {'route'} elseif ($line.Contains('BOT_ESCAPE ')) {'escape'} else {'decision'}
        $events.Add($k)
    } elseif ($legacyActive -and $line -match '\[(\d\d:\d\d:\d\d)\].*BOT_MOTION slot=(\d+) mode=(\d+) hp=(-?\d+) pos=Vector3 \{ x: ([-+\d.eE]+), y: ([-+\d.eE]+), z: ([-+\d.eE]+) \} horizontal_delta=([\d.]+).*move=Vector3 \{ x: ([-+\d.eE]+), y: ([-+\d.eE]+)') {
        $m = $Matches.Clone()
        $stamp = [TimeSpan]::Parse($m[1], $culture).TotalSeconds
        if ($null -eq $legacyStart) { $legacyStart = $stamp }
        $k = @{epoch=$legacyEpoch; map=$map; t=([Math]::Floor(($stamp-$legacyStart)/10)*10);
            slot=$m[2]; id=([int]$m[2]+1); team=0; bot=1; alive=([int]([int]$m[4] -gt 0));
            titan=([int]([int]$m[4] -gt 100)); hp=$m[4]; x=$m[5]; y=$m[6]; z=$m[7]}
        $row = Row $k; $row.source = 'legacy';
        $row.state = if ([double]$m[9] -ne 0 -or [double]$m[10] -ne 0) {'pursue'} else {'unknown'}
        $legacy.Add($row)
    }
}
$structured = $rows.Count -gt 0
if (-not $structured) { $rows = $legacy }
if ($rows.Count -eq 0) { throw 'No bot/player observations found in this log.' }
foreach ($row in $rows) {
    $key = "$($row.epoch)|$($row.map)|$($row.t.ToString('F2', $culture))"
    if ($frameModes.ContainsKey($key)) { $row.coordination = $frameModes[$key] }
    if ($frameRecovery.ContainsKey($key)) { $row.route_recovery = $frameRecovery[$key] }
}
$frameGroups = @($rows | Group-Object epoch,map,t)
foreach ($frame in $frameGroups) {
    foreach ($row in $frame.Group) {
        if (-not $row.alive -or $row.team -eq 0) { continue }
        $count = 0
        foreach ($other in $frame.Group) {
            if ($other.slot -eq $row.slot -or -not $other.alive -or $other.team -ne $row.team) { continue }
            $dx=$row.x-$other.x; $dy=$row.y-$other.y
            if ($dx*$dx+$dy*$dy -lt 140*140 -and [Math]::Abs($row.z-$other.z) -lt 96) { $count++ }
        }
        $row.near_allies = $count
    }
}
$botStats = [Collections.Generic.List[object]]::new()
foreach ($group in ($rows | Where-Object bot -eq 1 | Group-Object epoch,map,slot)) {
    $samples = @($group.Group | Sort-Object t)
    $first = $samples[0]; $last = $samples[-1]
    for ($i=1; $i -lt $samples.Count; $i++) {
        $current = $samples[$i]
        if (-not $current.alive -or $current.state -notin @('pursue','recover','embark','retreat')) { continue }
        $old = -1
        for ($j=$i-1; $j -ge 0; $j--) {
            if (-not $samples[$j].alive) { break }
            if ($current.t-$samples[$j].t -ge 10) { $old=$j; break }
        }
        if ($old -ge 0 -and $current.t-$samples[$old].t -le 13) {
            $dx=$current.x-$samples[$old].x; $dy=$current.y-$samples[$old].y
            if ($dx*$dx+$dy*$dy -lt 50*50) { $current.stalled=1 }
        }
    }
    $active=@($samples | Where-Object alive -eq 1)
    $botStats.Add([pscustomobject]@{
        epoch=$first.epoch; map=$first.map; slot=$first.slot; team=$last.team; samples=$samples.Count;
        alive_samples=$active.Count; stalled_samples=@($samples | Where-Object stalled -eq 1).Count;
        crowded_samples=@($active | Where-Object near_allies -ge 2).Count;
        switches=($samples | Measure-Object switches -Maximum).Maximum;
        recoveries=($samples | Measure-Object recoveries -Maximum).Maximum;
        path_failures=($samples | Measure-Object path_failures -Maximum).Maximum;
        path_requests=($samples | Measure-Object path_requests -Maximum).Maximum;
        spacing_commands=($samples | Measure-Object spacing -Maximum).Maximum;
        failed_goal_skips=($samples | Measure-Object failed_goal_skips -Maximum).Maximum;
        retreats=($samples | Measure-Object retreats -Maximum).Maximum;
        start=$first.t; end=$last.t
    })
}
$summary = [Collections.Generic.List[object]]::new()
foreach ($group in ($rows | Group-Object epoch,map)) {
    $points=@($group.Group); $first=$points[0]
    $bots=@($points | Where-Object bot -eq 1)
    $active=@($bots | Where-Object alive -eq 1)
    $stats=@($botStats | Where-Object {$_.epoch -eq $first.epoch -and $_.map -eq $first.map})
    $shares=[Collections.Generic.List[double]]::new()
    foreach ($frame in ($bots | Where-Object {$_.alive -and -not $_.titan -and $_.state -eq 'pursue' -and $_.target -ne -1} | Group-Object t,team)) {
        if ($frame.Count -ge 3) {
            $max=($frame.Group | Group-Object target | Measure-Object Count -Maximum).Maximum
            $shares.Add($max/$frame.Count)
        }
    }
    $summary.Add([pscustomobject]@{
        epoch=$first.epoch; map=$first.map; bot_slots=@($bots.slot | Sort-Object -Unique).Count;
        player_slots=@($points.slot | Sort-Object -Unique).Count; observations=$bots.Count;
        alive_observations=$active.Count; stalled_observations=@($bots | Where-Object stalled -eq 1).Count;
        crowded_observations=@($active | Where-Object near_allies -ge 2).Count;
        switches=($stats | Measure-Object switches -Sum).Sum;
        recoveries=($stats | Measure-Object recoveries -Sum).Sum;
        path_failures=($stats | Measure-Object path_failures -Sum).Sum;
        path_requests=($stats | Measure-Object path_requests -Sum).Sum;
        failed_goal_skips=($stats | Measure-Object failed_goal_skips -Sum).Sum;
        retreats=($stats | Measure-Object retreats -Sum).Sum;
        mean_largest_pursuit_share=if ($shares.Count) {[Math]::Round(($shares | Measure-Object -Average).Average,3)} else {$null};
        coordination=@($points.coordination | Sort-Object -Unique);
        route_recovery=@($points.route_recovery | Sort-Object -Unique);
        duration=[Math]::Round(($points | Measure-Object t -Maximum).Maximum-($points | Measure-Object t -Minimum).Minimum,1)
    })
}
$metadata=[pscustomobject]@{
    source_log=$LogPath; exported=(Get-Date).ToString('o'); structured=$structured;
    build_line=($raw | Select-String 'local build:' | Select-Object -First 1).Line;
    bot_joins=@($raw | Select-String 'spawned a bot :').Count;
    error_lines=@($raw | Select-String 'SCRIPT ERROR|Exception Access Violation|panicked at|FATAL ERROR').Count;
    limitations='Position samples, not screen video. Stall flags require <50 units of displacement over at least 10 seconds while pursuing/recovering. Clustering ignores walls. Legacy logs lack teams, human positions, targets and exact alive state.'
}
$rows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'observations.csv') -NoTypeInformation
$botStats | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'bots.csv') -NoTypeInformation
ConvertTo-Json -InputObject ($summary.ToArray()) -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'summary.json')
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'metadata.json')
ConvertTo-Json -InputObject ($events.ToArray()) -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'events.json')
$raw | ForEach-Object { $_ -replace '(?i)((?:token|tokencode|authToken|userToken|password)=)[^&\s"]+', '${1}[redacted]' } |
    Set-Content -LiteralPath (Join-Path $OutputDirectory 'archived.log')
$data=[pscustomobject]@{metadata=$metadata; rows=$rows.ToArray(); summary=$summary.ToArray(); events=$events.ToArray()}
$json=($data | ConvertTo-Json -Depth 8 -Compress).Replace('<','\u003c')
$template=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'replay-template.html') -Raw
$template.Replace('/*SESSION_DATA*/null', $json) | Set-Content -LiteralPath (Join-Path $OutputDirectory 'replay.html')
$summary.ToArray() | Format-Table map,bot_slots,observations,stalled_observations,switches,recoveries,path_failures,coordination -AutoSize
"Replay: $(Join-Path $OutputDirectory 'replay.html')"
if ($Open) { Start-Process -FilePath (Join-Path $OutputDirectory 'replay.html') }
