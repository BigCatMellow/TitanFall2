param([Parameter(Mandatory=$true)][string]$BatchDirectory)
# Independent, bounded report worker. Reads archived completed-match logs;
# writes reports only. It never starts/stops a game or edits a game profile.
$ErrorActionPreference='Stop'
$batch=[IO.Path]::GetFullPath($BatchDirectory)
$allowed="$env:USERPROFILE\northstar-crash-audit\Notes\map-surveys\"
if(-not $batch.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected batch path'}
$out=Join-Path $batch 'analysis'
New-Item -ItemType Directory -Path $out -Force|Out-Null
$plan=Get-Content -Raw -LiteralPath "$batch\plan.json"|ConvertFrom-Json
$records=[Collections.Generic.List[object]]::new()
$seen=@{}; $state='waiting'; $batchState='unknown'; $failure=$null
function Save {
    $data=[ordered]@{state=$state;updated=(Get-Date).ToString('o');batch_state=$batchState;results=$records.ToArray();failure=$failure}
    $data|ConvertTo-Json -Depth 9|Set-Content -LiteralPath "$out\status.tmp"
    Move-Item -LiteralPath "$out\status.tmp" -Destination "$out\status.json" -Force
    $lines=@('# Navigation context follow-up','',('Report worker: '+$state),('Game queue: '+$batchState),'',
        'Read-only analysis of archived matches. The game/mod settings remain frozen by the separate match runner. Geometry is an installed navigation surface, not collision scenery. Motion uses approximately 10-second samples and preceding player context.',
        '', '| Map | Result | Low-progress navigation samples / eligible motion samples | Low-progress next-point height >180 |',
        '|---|---|---:|---:|')
    foreach($r in $records){$lines+='| {0} | {1} | {2}/{3} | {4} |' -f $r.map,$r.state,$r.low_progress,$r.navigation_samples,$r.high_waypoints}
    $lines+=@('','Successfully analyzed map folders contain waypoint-motion.csv, summary.json, navigation geometry and an overview with stalled pilot observations. Report errors are recorded separately. Sample counts are not unique incidents. No causal fix or gameplay improvement is established by these reports.')
    if($failure){$lines+=@('',('Worker error: '+$failure))}
    [IO.File]::WriteAllLines("$out\Summary.md",$lines,[Text.UTF8Encoding]::new($false))
}
try {
    # Match runner permits 25 minutes per map; the report worker must outlive
    # a full installed-map queue, rather than stopping after the old 3-map run.
    $waitMinutes=[Math]::Max(70,25*@($plan.maps).Count+30)
    $deadline=(Get-Date).AddMinutes($waitMinutes)
    while($true){
        $s=Get-Content -Raw -LiteralPath "$batch\status.json"|ConvertFrom-Json
        $batchState=$s.state
        foreach($r in @($s.results)){
            if($seen.ContainsKey([string]$r.map)){continue}
            $seen[[string]$r.map]=$true
            $state='analyzing';Save
            $mapOut=Join-Path $out $r.map
            $record=[ordered]@{map=$r.map;state='complete';navigation_samples=$null;low_progress=$null;high_waypoints=$null;error=$null}
            try {
                & "$PSScriptRoot\Review-WaypointMotion.ps1" -LogPath "$($r.directory)\main\raw-session.log" -OutputDirectory "$mapOut\waypoints"|Out-Null
                $m=Get-Content -Raw -LiteralPath "$mapOut\waypoints\summary.json"|ConvertFrom-Json
                $record.navigation_samples=$m.navigation_samples
                $record.low_progress=$m.low_progress_navigation_samples
                $record.high_waypoints=$m.low_progress_waypoint_height_over_180
                $obs=Join-Path $r.directory ("main\reports\01-$($r.map)\movement\observations.csv")
                $nav="$env:USERPROFILE\northstar-crash-audit\map-cycle-test-profile\mods\Northstar.CustomServers\mod\maps\navmesh\$($r.map)_small.nm"
                if((Test-Path -LiteralPath $obs)-and(Test-Path -LiteralPath $nav)){
                    & "$PSScriptRoot\Export-NavMeshContext.ps1" -NavPath $nav -OutputDirectory "$mapOut\navmesh" -Observations $obs|Out-Null
                }else{throw 'Completed-match observations or mesh missing'}
            }catch{$record.state='report_error';$record.error=[string]$_}
            $records.Add([pscustomobject]$record)
            Save
        }
        if($s.state -in @('complete','finished_with_issues','stopped_error','stopped_by_request')){
            $state=if(@($records|Where-Object state -ne complete).Count){'complete_with_report_errors'}else{'complete'}
            break
        }
        if((Get-Date)-ge$deadline){$state='timed_out';$failure="Report worker reached its $waitMinutes-minute bound; game queue is independent";break}
        $state='waiting';Save
        Start-Sleep -Seconds 20
    }
}catch{$state='stopped_error';$failure=[string]$_}finally{Save}
