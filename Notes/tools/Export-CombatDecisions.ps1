param([Parameter(Mandatory=$true)][string]$LogPath, [string]$OutputDirectory)
$ErrorActionPreference='Stop'
if(-not $OutputDirectory) { $OutputDirectory=Join-Path (Split-Path $PSScriptRoot) ('sessions\combat-'+[IO.Path]::GetFileNameWithoutExtension($LogPath).Replace(' ','_')) }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
function Fields([string]$line) {
    $bag=@{}
    foreach($m in [regex]::Matches($line,'(?:^|\s)([a-z_]+)=([^\s]+)')) { $bag[$m.Groups[1].Value]=$m.Groups[2].Value }
    return $bag
}
$culture=[Globalization.CultureInfo]::InvariantCulture
function Num($bag,$key) { if($bag -and $bag.ContainsKey($key)) { return [double]::Parse($bag[$key],$culture) }; return 0.0 }
$players=@{}; $traces=@{}; $rows=[Collections.Generic.List[object]]::new(); $markers=[Collections.Generic.List[string]]::new(); $errors=[Collections.Generic.List[string]]::new()
foreach($line in (Get-Content -LiteralPath $LogPath)) {
    if($line -match 'COMBAT_TEST:') { $markers.Add($line) }
    if($line -match 'SCRIPT ERROR|COMPILE ERROR|Access violation|panicked|\[error\]') { $errors.Add($line) }
    if($line -match 'BOT_PLAYER epoch=') { $f=Fields $line; $players["$($f.epoch)/$($f.slot)"]=$f }
    if($line -match 'BOT_TRACE epoch=') { $f=Fields $line; $traces["$($f.epoch)/$($f.slot)/$($f.t)"]=$f }
    if($line -match 'BOT_COMBAT epoch=') {
        $f=Fields $line; $p=$players["$($f.epoch)/$($f.slot)"]
        $rows.Add([pscustomobject]@{epoch=[int](Num $f epoch);map=$f.map;t=(Num $f t);slot=[int](Num $f slot);weapon=$f.weapon;clip=[int](Num $f clip);reloading=[int](Num $f reloading);tactic=$f.tactic;reload_requests=[int](Num $f reload_requests);holds=[int](Num $f holds);retreats=[int](Num $f retreats);blocked_steps=[int](Num $f blocked_steps);alive=($p -and $p.alive -eq '1');titan=($p -and $p.titan -eq '1')})
    }
}
foreach($r in $rows) {
    $key="$($r.epoch)/$($r.slot)/$($r.t.ToString('F2',$culture))"
    $trace=$traces[$key]
    $r | Add-Member speed (Num $trace speed)
    $r | Add-Member state ([string]$trace.state)
}
$summary=@(foreach($g in $rows | Where-Object { $_.alive -and -not $_.titan -and $_.tactic -ne 'legacy' } | Group-Object map) {
    [pscustomobject]@{map=$g.Name;pilot_samples=$g.Count;bots=@($g.Group.slot | Sort-Object -Unique).Count;weapons=@($g.Group.weapon | Sort-Object -Unique);tactics=@($g.Group | Group-Object tactic | Select-Object Name,Count);reload_samples=@($g.Group | Where-Object reloading -eq 1).Count;moving_over_100=@($g.Group | Where-Object speed -gt 100).Count;negative_clip_samples=@($g.Group | Where-Object clip -lt 0).Count;maximum_clip=($g.Group.clip | Measure-Object -Maximum).Maximum}
})
[pscustomobject]@{log=$LogPath;summary=$summary;markers=$markers.ToArray();error_count=$errors.Count;errors=$errors.ToArray();limitations='Two-second snapshots; a range hold can intentionally have low speed. Short random encounters and a largely idle human cannot establish improved difficulty or win rate.'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'combat-summary.json')
$rows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'combat.csv') -NoTypeInformation
$summary | ConvertTo-Json -Depth 6
