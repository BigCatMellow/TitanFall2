param([string]$Session="$env:USERPROFILE\northstar-crash-audit\Notes\sessions\nslog2026-10-24_23-16-24",[string]$Combat="$env:USERPROFILE\northstar-crash-audit\Notes\sessions\combat-nslog2026-10-24_23-16-24\combat.csv")
$ErrorActionPreference='Stop'
$rows=Import-Csv (Join-Path $Session 'observations.csv'); $combatRows=Import-Csv $Combat; $culture=[Globalization.CultureInfo]::InvariantCulture
function Key($r) { "$($r.epoch)|$($r.slot)|$(([double]$r.t).ToString('F2',$culture))" }
$index=@{}; foreach($c in $combatRows){$index[(Key $c)]=$c}
$pilots=@(foreach($r in $rows) {
    if($r.bot -ne '1' -or $r.alive -ne '1' -or $r.titan -ne '0'){continue}
    $c=$index[(Key $r)]; $distance=[Math]::Sqrt([Math]::Pow(([double]$r.x-[double]$r.tx),2)+[Math]::Pow(([double]$r.y-[double]$r.ty),2))
    [pscustomobject]@{epoch=[int]$r.epoch;map=$r.map;slot=[int]$r.slot;id=$r.id;t=[double]$r.t;x=[double]$r.x;y=[double]$r.y;z=[double]$r.z;hp=[int]$r.hp;state=$r.state;visible=[int]$r.visible;stalled=[int]$r.stalled;speed=[double]$r.speed;distance=$distance;height=[double]$r.tz-[double]$r.z;target=[int]$r.target;weapon=$c.weapon;clip=if($c){[int]$c.clip}else{-999};reloading=if($c){[int]$c.reloading}else{-1};tactic=$c.tactic;blocked=if($c){[int]$c.blocked_steps}else{0};grid=('{0},{1},{2}' -f ([Math]::Round([double]$r.x/128)*128),([Math]::Round([double]$r.y/128)*128),([Math]::Round([double]$r.z/64)*64))}
})
$rounds=@(foreach($g in $pilots | Group-Object epoch,map) { $p=$g.Group; $s=@($p|Where-Object stalled -eq 1); [pscustomobject]@{round=$g.Name;pilot_samples=$p.Count;stalls=$s.Count;stall_percent=[Math]::Round(100*$s.Count/[Math]::Max(1,$p.Count),2);stall_height_over_180=@($s|Where-Object{[Math]::Abs($_.height)-gt180}).Count;recover_samples=@($p|Where-Object state -eq recover).Count;hold_samples=@($p|Where-Object tactic -like '*hold').Count;stopped_holds=@($p|Where-Object{$_.tactic -like '*hold' -and $_.speed -lt20}).Count;empty_not_reloading=@($p|Where-Object{$_.clip -eq0 -and $_.reloading -eq0 -and $_.tactic -ne 'legacy'}).Count} })
$clusters=@($pilots | Where-Object stalled -eq 1 | Group-Object map,grid | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { [pscustomobject]@{area=$_.Name;samples=$_.Count;slots=@($_.Group.slot|Sort-Object -Unique);height_median=($_.Group.height|Sort-Object)[[int]($_.Count/2)];states=@($_.Group.state|Sort-Object -Unique);target_ids=@($_.Group.target|Sort-Object -Unique)} })
$episodes=[Collections.Generic.List[object]]::new()
foreach($g in $pilots|Group-Object epoch,slot){
    $a=@($g.Group|Sort-Object t)
    foreach($kind in @('stall','empty','reload','blocked_hold')){
        $start=$null;$last=$null;$count=0;$prev=$null
        foreach($r in $a){
            $match=switch($kind){stall{$r.stalled -eq1};empty{$r.clip-eq0 -and $r.reloading-eq0 -and $r.tactic-ne'legacy'};reload{$r.reloading-eq1 -and $r.tactic-ne'legacy'};blocked_hold{$r.tactic-like'*hold' -and $r.speed-lt20 -and $prev -and $r.blocked-gt$prev.blocked}}
            if($match -and ($null-eq$last -or ($r.t-$last.t-le2.1 -and $r.id-eq$last.id))){if($null-eq$start){$start=$r};$last=$r;$count++}
            else {
                if($null-ne$start){$episodes.Add([pscustomobject]@{kind=$kind;map=$start.map;epoch=$start.epoch;slot=$start.slot;start=$start.t;end=$last.t;span=$last.t-$start.t;count=$count;x=$start.x;y=$start.y;z=$start.z;target=$start.target;height=$start.height})}
                if($match){$start=$r;$last=$r;$count=1}else{$start=$null;$last=$null;$count=0}
            }
            $prev=$r
        }
        if($null-ne$start){$episodes.Add([pscustomobject]@{kind=$kind;map=$start.map;epoch=$start.epoch;slot=$start.slot;start=$start.t;end=$last.t;span=$last.t-$start.t;count=$count;x=$start.x;y=$start.y;z=$start.z;target=$start.target;height=$start.height})}
    }
}
$events=Get-Content -Raw (Join-Path $Session 'events.json')|ConvertFrom-Json
$churn=@(foreach($g in $events|Where-Object kind -eq decision|Group-Object epoch){$reversals=0;$visible=0;foreach($b in $g.Group|Group-Object slot){$previous=$null;foreach($e in $b.Group|Sort-Object{[double]$_.t}){if($previous -and [double]$e.t-[double]$previous.t-le0.5 -and $e.old-eq$previous.target -and $e.target-eq$previous.old){$reversals++;if($e.reason-eq'engage' -and $previous.reason-eq'engage'){$visible++}};$previous=$e}};[pscustomobject]@{epoch=$g.Name;switches=$g.Count;reversals_within_half_second=$reversals;both_visible_reversals=$visible}})
$results=[pscustomobject]@{rounds=$rounds;stall_clusters=$clusters;longest_episodes=@($episodes|Group-Object kind|ForEach-Object{$_.Group|Sort-Object span -Descending|Select-Object -First 5});target_churn=$churn}
$results|ConvertTo-Json -Depth 8|Set-Content (Join-Path $Session 'fine-tune-review.json')
$pilots|Export-Csv (Join-Path $Session 'pilot-combat-joined.csv') -NoTypeInformation
$results|ConvertTo-Json -Depth 8
