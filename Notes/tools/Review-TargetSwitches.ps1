param([Parameter(Mandatory=$true)][string]$LogPath,[Parameter(Mandatory=$true)][string]$OutputDirectory)
# Offline evidence only: preceding 2-second actor snapshots do not establish
# simultaneous visibility or which target was shootable at decision time.
$ErrorActionPreference='Stop'
$culture=[Globalization.CultureInfo]::InvariantCulture
function Fields([string]$line){
    $f=@{};foreach($m in [regex]::Matches($line,'(?:^|\s)([a-z_]+)=([^\s]+)')){$f[$m.Groups[1].Value]=$m.Groups[2].Value};return $f
}
function Num($s){return [double]::Parse([string]$s,$culture)}
function XY($a,$b){return [Math]::Sqrt([Math]::Pow((Num $a.x)-(Num $b.x),2)+[Math]::Pow((Num $a.y)-(Num $b.y),2))}
$path=(Resolve-Path -LiteralPath $LogPath).Path
$hasSurvey=$false
foreach($line in [IO.File]::ReadLines($path)){if($line.Contains('MAP_SURVEY_BEGIN ')){$hasSurvey=$true;break}}
$measuring=-not$hasSurvey;$frame=$null
$players=@{};$actors=@{};$previous=@{};$pendingCombat=@{}
$switches=[Collections.Generic.List[object]]::new();$combat=[Collections.Generic.List[object]]::new()
foreach($line in [IO.File]::ReadLines($path)){
    if($line.Contains('MAP_SURVEY_BEGIN ')){$measuring=$true;$previous=@{}}
    elseif($line.Contains('MAP_SURVEY_RESULT ')-or$line.Contains('MAP_SURVEY_DONE ')){$measuring=$false}
    elseif($line.Contains('BOT_FRAME ')){$frame=Fields $line}
    elseif($line.Contains('BOT_PLAYER ')){
        $f=Fields $line;$players["$($f.epoch)|$($f.slot)"]=$f;$actors["$($f.epoch)|$($f.id)"]=$f
    }
    elseif($line.Contains('BOT_COMBAT ')){
        $f=Fields $line;$pendingCombat["$($f.epoch)|$($f.slot)|$($f.t)"]=$f
    }
    elseif($measuring -and $line.Contains('BOT_TRACE ')){
        $f=Fields $line;$key="$($f.epoch)|$($f.slot)|$($f.t)";$c=$pendingCombat[$key];$p=$players["$($f.epoch)|$($f.slot)"]
        if($c -and $p -and $p.t-eq$f.t -and $p.bot-eq'1' -and $p.alive-eq'1' -and $p.titan-eq'0' -and $c.tactic-ne'legacy'){
            $combat.Add([pscustomobject]@{map=$f.map;epoch=$f.epoch;t=Num $f.t;slot=[int]$f.slot;state=$f.state;visible=[int]$f.visible;weapon=$c.weapon;clip=[int]$c.clip;reloading=[int]$c.reloading;tactic=$c.tactic;active=if($c.ContainsKey('active')){$c.active}else{'unknown'}})
        }
        [void]$pendingCombat.Remove($key)
    }
    elseif($measuring -and $line.Contains('BOT_DECISION ')){
        $f=Fields $line;$now=Num $f.t;$key="$($f.epoch)|$($f.slot)";$prev=$previous[$key]
        $p=$players[$key];$old=$actors["$($f.epoch)|$($f.old)"];$new=$actors["$($f.epoch)|$($f.target)"]
        $recent=$p -and $p.bot-eq'1' -and $now-(Num $p.t)-ge0 -and $now-(Num $p.t)-le2.1
        $actorContext=if(-not$recent){'unknown'}elseif($p.alive-ne'1'){'dead_at_prior_frame'}elseif($p.titan-eq'1'){'titan_at_prior_frame'}else{'pilot_at_prior_frame'}
        $pilot=$actorContext-eq'pilot_at_prior_frame'
        $context=$pilot -and $old -and $new -and $old.alive-eq'1' -and $new.alive-eq'1'
        if($context){foreach($actor in @($old,$new)){if($now-(Num $actor.t)-lt0 -or $now-(Num $actor.t)-gt2.1){$context=$false}}}
        $od=if($context){XY $p $old}else{$null};$nd=if($context){XY $p $new}else{$null}
        $reverse=$prev -and $now-(Num $prev.t)-ge0 -and $now-(Num $prev.t)-le0.5 -and $f.old-eq$prev.target -and $f.target-eq$prev.old
        $switches.Add([pscustomobject][ordered]@{
            map=$frame.map;epoch=$f.epoch;t=$now;slot=[int]$f.slot;old=$f.old;target=$f.target;reason=$f.reason
            previous_reason=if($prev){$prev.reason}else{''};seconds_since_previous=if($prev){[Math]::Round($now-(Num $prev.t),3)}else{$null}
            quick_reversal=[int][bool]$reverse;pilot_context=[int][bool]$pilot;actor_context=$actorContext;exact_actor=if($f.ContainsKey('actor')){$f.actor}else{'unknown'};both_targets_observed_alive=[int][bool]$context
            old_xy=if($context){[Math]::Round($od,2)}else{$null};new_xy=if($context){[Math]::Round($nd,2)}else{$null}
            both_inside_400=[int]($context -and $od-le400 -and $nd-le400)
            old_titan=if($context){$old.titan}else{$null};new_titan=if($context){$new.titan}else{$null}
        })
        $previous[$key]=$f
    }
}
if($switches.Count-eq0){throw 'No measured target-switch events'}
$reversals=@($switches|Where-Object quick_reversal -eq 1)
$pilots=@($reversals|Where-Object pilot_context -eq 1)
$known=@($pilots|Where-Object both_targets_observed_alive -eq 1)
$empty=@($combat|Where-Object{$_.clip-eq0 -and $_.reloading-eq0})
$result=[ordered]@{
    log=$path;scope=if($hasSurvey){'Survey measurement only; warmup/post-result excluded'}else{'Whole log'}
    switches=$switches.Count;quick_reversals=$reversals.Count
    quick_reversal_percent=[Math]::Round(100*$reversals.Count/[Math]::Max(1,$switches.Count),2)
    reversal_reason_pairs=@($reversals|Group-Object previous_reason,reason|ForEach-Object{[pscustomobject]@{pair=$_.Name;count=$_.Count}})
    by_prior_actor_context=@($switches|Group-Object actor_context|ForEach-Object{
        $g=@($_.Group);$n=@($g|Where-Object quick_reversal -eq 1).Count
        [pscustomobject]@{context=$_.Name;switches=$g.Count;quick_reversals=$n;percent=[Math]::Round(100*$n/[Math]::Max(1,$g.Count),2)}
    })
    by_exact_actor_when_logged=@($switches|Group-Object exact_actor|ForEach-Object{
        $g=@($_.Group);$n=@($g|Where-Object quick_reversal -eq 1).Count
        [pscustomobject]@{actor=$_.Name;switches=$g.Count;quick_reversals=$n}
    })
    quick_reversals_with_recent_pilot_context=$pilots.Count
    those_with_both_targets_recently_observed_alive=$known.Count
    those_with_both_targets_within_400_xy=@($known|Where-Object both_inside_400 -eq 1).Count
    matched_pilot_combat_snapshots=$combat.Count
    observed_weapons=@($combat.weapon|Sort-Object -Unique)
    empty_not_reloading_snapshots=$empty.Count
    empty_snapshot_states=@($empty|Group-Object state|ForEach-Object{[pscustomobject]@{state=$_.Name;count=$_.Count}})
    combat_freshness_when_logged=@($combat|Group-Object active|ForEach-Object{[pscustomobject]@{active=$_.Name;samples=$_.Count}})
    empty_current_command_snapshots=@($empty|Where-Object active -eq '1').Count
    nonlegacy_combat_snapshots_during_embark=@($combat|Where-Object state -eq embark).Count
    limits='Quick reversal means adjacent logged A->B->A switches within0.5seconds, not proven wasted fire. Recent actor state is at most2.1seconds old; targets can move/die or lose visibility between snapshots. Both-inside400 uses observed XY distance, not a confirmed urgent-ranking cause. An engage/engage reason pair only says each selected target was shootable at its respective decision. CombatState can remain stale when its decision block is bypassed, especially while boarding or owning a pet Titan. Empty/blocked snapshots are investigative signals, not confirmed failures. Survey weapon coverage is reported explicitly.'
}
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
$switches.ToArray()|Export-Csv -LiteralPath (Join-Path $OutputDirectory 'switches.csv') -NoTypeInformation
$combat.ToArray()|Export-Csv -LiteralPath (Join-Path $OutputDirectory 'combat-snapshots.csv') -NoTypeInformation
$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $OutputDirectory 'summary.json')
$result|ConvertTo-Json -Depth 6
