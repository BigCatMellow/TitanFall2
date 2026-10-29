param([Parameter(Mandatory)][string]$RequestPath)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Read-RouteStudyValidation.ps1"
. "$PSScriptRoot/Read-SurveyQueueJson.ps1"
. "$PSScriptRoot/Write-SurveyQueueJson.ps1"
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
. "$PSScriptRoot/Northstar-ModState.ps1"
$request=Get-Content $RequestPath -Raw|ConvertFrom-Json
$profile=(Resolve-Path $request.profile).Path
$deadline=[datetime]$request.deadline
$batch=[string]$request.batch
$public=Join-Path $repo 'research/routing-v24-20261029'
$frozen=Read-RouteStudyValidation $request.validation $profile
if((Get-Date)-ge$deadline){throw 'Study deadline has passed'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is already running'}
if(Test-Path $batch){throw 'Preserve existing study'}
New-Item -ItemType Directory -Path $batch,$public -Force|Out-Null
Copy-Item $RequestPath "$batch/request.json"
$normalFiles=@(Get-ChildItem "$($request.normal_profile)/save_data" -Recurse -File|ForEach-Object {$_.FullName})
$normalFiles+=@('plugins/bp_ort.dll','enabledmods.json','bt7274-candidate.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')|ForEach-Object {Join-Path $request.normal_profile $_}
$guard=@($normalFiles|ForEach-Object {@{path=$_;hash=(Get-FileHash -LiteralPath $_).Hash}})
$guard|ConvertTo-Json|Set-Content "$batch/private-normal-guard.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');deadline=$deadline.ToString('o');planned=$request.rounds.Count;results=@();failures=@();skipped=@();current=$null;candidate_stopped=$false;profile_restored=$false;normal_unchanged=$true;failure=$null}
function Save-Study {
    $state.updated=(Get-Date).ToString('o')
    Write-SurveyQueueJson "$batch/status.json" $state
    $safe=@($state.results|ForEach-Object {@{map=$_.map;repeat=$_.repeat;variant=$_.variant;metrics=$_.metrics}})
    $pairs=@(foreach($group in $safe|Group-Object map,repeat){
        $off=@($group.Group|Where-Object variant -eq 0);$on=@($group.Group|Where-Object variant -eq 1)
        if($off.Count-eq1-and$on.Count-eq1){@{map=$on[0].map;repeat=$on[0].repeat;off_low=$off[0].metrics.low_progress_percent;on_low=$on[0].metrics.low_progress_percent}}
    })
    $snapshot=[ordered]@{schema_version=1;state=$state.state;started=$state.started;updated=$state.updated;deadline=$state.deadline;planned=$state.planned;completed=$safe.Count;failed_attempts=$state.failures.Count;candidate_stopped=$state.candidate_stopped;normal_unchanged=$state.normal_unchanged;profile_restored=$state.profile_restored;native_sha256=$frozen.dll_sha256;measurement_sha256=$frozen.measurement_sha256;goal=$request.goal;source_commit=$request.source_commit;rounds=$safe;pairs=$pairs;limits='Sequential reversed-order bot-only pairs; not randomized human difficulty evidence. Native and measurement build frozen. Pilot low-progress metric overlaps; global trial may also affect Titan routing. Candidate operational stop is not statistical significance or a deployment gate. Raw logs/saves/identifiers remain private. No automatic normal deployment.'}
    try{Write-SurveyQueueJson "$public/status.json" $snapshot}catch{$state.public_report_error=[string]$_}
}
function Check-Normal {
    foreach($g in $guard){if((Get-FileHash -LiteralPath $g.path).Hash-ne$g.hash){$state.normal_unchanged=$false;throw 'Normal profile changed; stop study for player activity'}}
}
function Check-Regression {
    foreach($group in $state.results|Group-Object map,repeat){
        $off=@($group.Group|Where-Object variant -eq 0);$on=@($group.Group|Where-Object variant -eq 1)
        if($off.Count-ne1-or$on.Count-ne1){continue}
        $a=$off[0].metrics;$b=$on[0].metrics
        if($a.live_pilot_samples-ge500-and$b.live_pilot_samples-ge500-and$null-ne$a.low_progress_percent-and$null-ne$b.low_progress_percent-and$b.low_progress_percent-gt($a.low_progress_percent+5)-and$b.low_progress_percent-gt(1.5*$a.low_progress_percent)){$state.candidate_stopped=$true}
    }
}
$child=$null;$awake=$false
try{
    Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class RouteStudyPower { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags); }
'@
    if([RouteStudyPower]::SetThreadExecutionState([uint32]2147483649)-eq0){throw 'Cannot establish sleep guard'};$awake=$true
    $hostExe=(Get-Process -Id $PID).Path
    $index=0
    foreach($round in $request.rounds){
        if((Get-Date).AddMinutes(8)-gt$deadline){$state.state='stopped_time_budget';break}
        if(Test-Path "$batch/stop-after-current.txt"){$state.state='stopped_by_request';break}
        if($state.candidate_stopped-and[int]$round.variant-eq1){$state.skipped+=@{map=$round.map;variant=1;reason='Operational regression cutoff'};Save-Study;continue}
        Check-Normal
        $check=Read-RouteStudyValidation $request.validation $profile
        foreach($field in @('dll_sha256','core_sha256','bridge_sha256','measurement_sha256')){if($check.$field-ne$frozen.$field){throw 'Frozen study runtime changed'}}
        if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared'}
        $index++;$dir=Join-Path $batch ('{0:D2}-{1}-r{2}-variant{3}'-f$index,$round.map,$round.repeat,$round.variant)
        $state.state='running';$state.current=@{index=$index;map=$round.map;variant=$round.variant;repeat=$round.repeat;directory=$dir;score=$null};Save-Study
        $childArgs=@('-NoProfile','-File',"$repo/tools/Run-CandidateSurvey.ps1",'-BatchDirectory',$dir,'-ValidationDirectory',[string]$request.validation,'-ReadinessRetestDirectory',[string]$request.validation,'-TestProfile',$profile,'-Goal',[string]$request.goal,'-MapNames',[string]$round.map,'-ObserverDefaults','-RouteStudy','-RouteVariant',[string]$round.variant)
        $child=Start-Process $hostExe -WindowStyle Hidden -WorkingDirectory $repo -PassThru -ArgumentList $childArgs -RedirectStandardOutput "$dir.stdout.log" -RedirectStandardError "$dir.stderr.log"
        $childDeadline=(Get-Date).AddMinutes(22)
        while(-not$child.HasExited){
            if(Test-Path "$dir/status.json"){
                $current=Read-SurveyQueueJson "$dir/status.json"
                $state.current.child_state=$current.state;$state.current.score=$current.current.score;$state.current.game_pid=$current.current.pid;Save-Study
                if((Get-Date)-ge$deadline-and$current.current.pid){
                    $owned=Get-Process -Id $current.current.pid -ErrorAction SilentlyContinue
                    if($owned){Stop-OwnedSurveyGame -Process $owned -Profile $profile}
                    $state.deadline_stop=$true
                }
            }
            if((Get-Date)-gt$childDeadline){throw 'Child watchdog exceeded; preserve ownership evidence'}
            Start-Sleep -Seconds 2;$child.Refresh()
        }
        $child=$null
        $current=Read-SurveyQueueJson "$dir/status.json"
        if($current.state-ne'complete'-or!$current.profile_restored-or$current.results.Count-ne1){
            $state.failures+=@{map=$round.map;variant=$round.variant;reason=$current.failure;directory=$dir}
            if($state.deadline_stop){$state.state='stopped_time_budget';break}
            if(!$current.profile_restored-or$current.failure-match'SCRIPT ERROR|COMPILE ERROR|BOT_MEASURE_ERROR|Frozen|Uncontrolled|switches'){throw 'Study integrity/runtime failure; retain failed attempt'}
            $state.state='between_rounds';Save-Study;continue
        }
        $raw=Join-Path $current.results[0].directory 'raw-session.log'
        & node --preserve-symlinks --preserve-symlinks-main "$repo/tools/Review-RouteStudy.mjs" --log $raw --out "$dir/metrics.json" > "$dir/analysis.stdout.log"
        if($LASTEXITCODE-ne0){throw 'Study analysis failed'}
        $m=Get-Content "$dir/metrics.json" -Raw|ConvertFrom-Json
        if($m.error_markers-ne0-or$m.variant-ne$round.variant-or$m.map-ne$round.map-or$m.goal-ne$request.goal){throw 'Study metrics mismatch'}
        $state.results+=@{map=$round.map;repeat=$round.repeat;variant=$round.variant;directory=$dir;metrics=$m}
        $state.state='between_rounds';Check-Normal;Check-Regression;Save-Study
    }
    if($state.state-in@('preparing','between_rounds')){$state.state='complete'}
}catch{$state.state='stopped_error';$state.failure=[string]$_}
finally{
    if($awake){[void][RouteStudyPower]::SetThreadExecutionState([uint32]2147483648)}
    $childAlive=$child-and-not$child.HasExited
    if($childAlive){$state.active_child_left_to_finish=$child.Id}
    if(!$childAlive-and!(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
        try{
            if((Get-FileHash "$profile/plugins/bp_ort.dll").Hash-ne$frozen.dll_sha256){throw 'Do not overwrite changed native'}
            foreach($rel in @('plugins/bp_ort.dll','enabledmods.json','bt7274-candidate.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')){if(Test-Path "$($request.rollback)/$rel"){Copy-Item "$($request.rollback)/$rel" "$profile/$rel" -Force}}
            $mods=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
            foreach($name in @('BT7274.MapSurvey','BT7274.SafetyTest','BT7274.RouteProbe','BT7274.BotMeasurements')){Disable-NorthstarMod $mods $name $profile}
            $mods|ConvertTo-Json -Depth 10|Set-Content "$profile/enabledmods.json"
            $state.profile_restored=$true
        }catch{$state.state='stopped_error';$state.failure+='; restore: '+[string]$_}
    }
    try{Check-Normal}catch{$state.failure+='; normal guard: '+[string]$_}
    $state.finished=(Get-Date).ToString('o');Save-Study
}
