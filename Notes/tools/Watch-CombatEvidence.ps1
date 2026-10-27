param([Parameter(Mandatory=$true)][string]$BatchDirectory)
# Read-only follow-up. The match queue and its navigation reports are independent.
$ErrorActionPreference='Stop'
$batch=[IO.Path]::GetFullPath($BatchDirectory)
if(-not $batch.StartsWith("$env:USERPROFILE\northstar-crash-audit\Notes\map-surveys\",[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected batch directory'}
$out=Join-Path $batch 'combat-evidence'
New-Item -ItemType Directory -Path $out -Force|Out-Null
$plan=Get-Content -Raw -LiteralPath "$batch\plan.json"|ConvertFrom-Json
$seen=@{};$records=[Collections.Generic.List[object]]::new();$state='waiting';$queue='unknown';$failure=$null
function Save {
    [ordered]@{state=$state;updated=(Get-Date).ToString('o');batch_state=$queue;results=$records.ToArray();failure=$failure}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath "$out\status.tmp"
    Move-Item -LiteralPath "$out\status.tmp" -Destination "$out\status.json" -Force
    $lines=@('# Combat evidence review','',('Worker: '+$state),('Queue: '+$queue),'',
        '| Map | Report | Pilot-context quick reversals | Titan-context quick reversals | Cached combat snapshots while boarding |',
        '|---|---|---:|---:|---:|')
    foreach($r in $records){$lines+='| {0} | {1} | {2}% | {3}% | {4} |' -f $r.map,$r.state,$r.pilot_percent,$r.titan_percent,$r.embark_combat_samples}
    $lines+=@('','Pilot/Titan contexts use preceding actor snapshots up to2.1seconds old. These are percentages of target-switch events, not time spent confused or missed shots. A rapid A-to-B-to-A reversal is not automatically a bad decision. Older v16 logs do not mark combat sample freshness; boarding snapshots may contain cached ammo/tactic values. Individual JSON/CSV reports preserve missing context and these limits. No gameplay settings are changed.')
    if($failure){$lines+=@('',('Error: '+$failure))}
    [IO.File]::WriteAllLines("$out\Summary.md",$lines,[Text.UTF8Encoding]::new($false))
}
try {
    $deadline=(Get-Date).AddMinutes([Math]::Max(70,25*@($plan.maps).Count+30))
    while($true){
        $s=Get-Content -Raw -LiteralPath "$batch\status.json"|ConvertFrom-Json;$queue=$s.state
        foreach($r in @($s.results)){
            if($seen.ContainsKey([string]$r.map)){continue};$seen[[string]$r.map]=$true;$state='analyzing';Save
            $row=[ordered]@{map=$r.map;state='complete';pilot_percent=$null;titan_percent=$null;embark_combat_samples=$null;error=$null}
            try {
                & "$PSScriptRoot\Review-TargetSwitches.ps1" -LogPath "$($r.directory)\main\raw-session.log" -OutputDirectory "$out\$($r.map)"|Out-Null
                $review=Get-Content -Raw -LiteralPath "$out\$($r.map)\summary.json"|ConvertFrom-Json
                $pilot=@($review.by_prior_actor_context|Where-Object context -eq pilot_at_prior_frame)|Select-Object -First 1
                $titan=@($review.by_prior_actor_context|Where-Object context -eq titan_at_prior_frame)|Select-Object -First 1
                if($pilot){$row.pilot_percent=$pilot.percent};if($titan){$row.titan_percent=$titan.percent}
                $row.embark_combat_samples=$review.nonlegacy_combat_snapshots_during_embark
            }catch{$row.state='report_error';$row.error=[string]$_}
            $records.Add([pscustomobject]$row);Save
        }
        if($queue-in@('complete','finished_with_issues','stopped_error','stopped_by_request')){
            $state=if(@($records|Where-Object state -ne complete).Count){'complete_with_report_errors'}else{'complete'};break
        }
        if((Get-Date)-ge$deadline){$state='timed_out';break}
        $state='waiting';Save;Start-Sleep -Seconds 20
    }
}catch{$state='stopped_error';$failure=[string]$_}finally{Save}
