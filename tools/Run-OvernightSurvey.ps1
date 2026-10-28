param([Parameter(Mandatory)][string]$RequestPath,[switch]$PlanOnly)
$ErrorActionPreference='Stop'
$request=Get-Content -Raw -LiteralPath $RequestPath|ConvertFrom-Json
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Read-SurveyQueueJson.ps1"
. "$PSScriptRoot/Read-SurveyRuntimeHash.ps1"
$batch=[string]$request.batch
$profile=[string]$request.profile
$goal=[int]$request.goal
$maxAttempts=[int]$request.max_attempts
if($goal-lt1-or$goal-gt9999-or$maxAttempts-lt1-or$maxAttempts-gt3){throw 'Invalid goal or retry bound'}
$catalog=Get-Content -Raw "$repo/Notes/map-surveys/all-maps-20261025-102025/plan.json"|ConvertFrom-Json
$priority=@('mp_forwardbase_kodai','mp_grave','mp_homestead','mp_relic02','mp_rise','mp_thaw','mp_wargames','mp_eden','mp_glitch','mp_angel_city')
$allMaps=@($priority)+@($catalog.maps|Where-Object {$_-notin$priority})
$nativeHash=(Get-FileHash "$profile/plugins/bp_ort.dll").Hash
$coreHash=(Get-FileHash "$profile/Northstar.dll").Hash
$bridge="$profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut"
$bridgeHash=(Get-FileHash $bridge).Hash
function Read-QueueJson([string]$path){
    Read-SurveyQueueJson $path
}
function Read-Prior {
    $rows=@()
    foreach($priorBatch in $request.completed_batches){
        $p=Get-Content -Raw "$priorBatch/plan.json"|ConvertFrom-Json
        $s=Get-Content -Raw "$priorBatch/status.json"|ConvertFrom-Json
        if((Read-SurveyRuntimeHash $p)-ne$nativeHash-or$p.core_sha256-ne$coreHash-or$p.bridge_sha256-ne$bridgeHash){throw 'Prior cohort runtime differs'}
        foreach($entry in $s.results){if($entry.result.valid-eq'true'){
            $rows+=@{map=$entry.map;goal=$p.goal;observer_loadout_restore=$p.observer_loadout_restore;result=$entry.result;directory=$entry.directory;batch=$priorBatch}
        }}
    }
    $rows
}
if($PlanOnly){
    $prior=@(Read-Prior)
    [ordered]@{goal=$goal;completed=@($prior|ForEach-Object {$_.map});remaining=@($allMaps|Where-Object {$_-notin$prior.map});max_attempts=$maxAttempts;observer_loadout_restore=$false}|ConvertTo-Json -Depth 5
    return
}
if(Test-Path -LiteralPath $batch){throw 'Preserve the existing overnight batch'}
New-Item -ItemType Directory -Path $batch|Out-Null
Copy-Item -LiteralPath $RequestPath -Destination "$batch/request.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');goal=$goal;total_maps=$allMaps.Count;prior_completed=@();results=@();current=$null;failure=$null;awake_guard=$false}
function Save-OvernightState {
    $state.updated=(Get-Date).ToString('o')
    $state|ConvertTo-Json -Depth 10|Set-Content "$batch/status.tmp"
    Move-Item -LiteralPath "$batch/status.tmp" -Destination "$batch/status.json" -Force
    $covered=@($state.prior_completed|ForEach-Object {$_.map})+@($state.results|Where-Object {$_.status-eq'passed'}|ForEach-Object {$_.map})
    [ordered]@{updated=$state.updated;state=$state.state;goal=$goal;completed_maps=@($covered|Select-Object -Unique);failed_maps=@($state.results|Where-Object {$_.status-eq'failed'}|ForEach-Object {$_.map});remaining_maps=@($allMaps|Where-Object {$_-notin$covered});excluded_maps=$catalog.excluded_maps;prior_results=$state.prior_completed;new_results=$state.results}|ConvertTo-Json -Depth 10|Set-Content "$batch/coverage.json"
}
function Check-FrozenRuntime {
    if((Get-FileHash "$profile/plugins/bp_ort.dll").Hash-ne$nativeHash-or(Get-FileHash "$profile/Northstar.dll").Hash-ne$coreHash-or(Get-FileHash $bridge).Hash-ne$bridgeHash){throw 'Frozen runtime changed; stop the overnight queue'}
}
$activeChild=$null
$normalHashes=@()
try{
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NorthstarSurveyPower {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint SetThreadExecutionState(uint flags);
}
'@
    if([NorthstarSurveyPower]::SetThreadExecutionState([uint32]2147483649)-eq0){throw 'Could not keep the survey process awake'}
    $state.awake_guard=$true
    if($request.wait_for_batch){
        $state.state='waiting_for_current_round';Save-OvernightState
        $deadline=(Get-Date).AddMinutes(30)
        do{
            $waiting=Read-QueueJson "$($request.wait_for_batch)/status.json"
            $state.current=@{map=$waiting.current.map;score=$waiting.current.score;previous_batch=$request.wait_for_batch};Save-OvernightState
            if($waiting.state-in@('stopped_by_request','stopped_error','complete')){break}
            if((Get-Date)-gt$deadline){throw 'Previous queue did not finish within thirty minutes'}
            Start-Sleep -Seconds 2
        }while($true)
        if(-not$waiting.profile_restored){throw 'Previous queue did not restore the idle profile'}
    }
    if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game is running; do not replace it'}
    $state.prior_completed=@(Read-Prior)
    $completed=@($state.prior_completed|ForEach-Object {$_.map})
    $remaining=@($allMaps|Where-Object {$_-notin$completed})
    $plan=[ordered]@{created=(Get-Date).ToString('o');maps=$remaining;all_maps=$allMaps;goal=$goal;minutes=15;bots=16;aim=0.78;max_attempts=$maxAttempts;observer_loadout_restore=$false;native_sha256=$nativeHash;core_sha256=$coreHash;bridge_sha256=$bridgeHash;completed_batches=$request.completed_batches;excluded_maps=$catalog.excluded_maps;failure_policy='Retry map-specific failures once, retain every attempt, continue with restored profile; stop on integrity/ownership/restoration failure'}
    $plan|ConvertTo-Json -Depth 6|Set-Content "$batch/plan.json"
    if($request.normal_profile){
        $normalHashes=@(Get-ChildItem "$($request.normal_profile)/save_data" -Recurse -File|ForEach-Object {@{path=$_.FullName;hash=(Get-FileHash -LiteralPath $_.FullName).Hash}})
        $normalHashes|ConvertTo-Json|Set-Content "$batch/private-normal-save-guard.json"
    }
    $hostExe=(Get-Process -Id $PID).Path
    $index=0
    foreach($map in $remaining){
        if(Test-Path "$batch/stop-after-current.txt"){$state.state='stopped_by_request';break}
        $index++;$attemptRows=@();$success=$null
        for($attempt=1;$attempt-le$maxAttempts;$attempt++){
            Check-FrozenRuntime
            if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared; overnight queue will not replace it'}
            $childBatch=Join-Path $batch ('{0:D2}-{1}-attempt{2}'-f$index,$map,$attempt)
            $state.state='running_map';$state.current=@{map=$map;index=$index;attempt=$attempt;batch=$childBatch;score=$null};Save-OvernightState
            $childArgs=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',"$repo/tools/Run-CandidateSurvey.ps1",'-BatchDirectory',$childBatch,'-ValidationDirectory',[string]$request.validation,'-ReadinessRetestDirectory',[string]$request.readiness_retest,'-TestProfile',$profile,'-Goal',"$goal",'-MapNames',$map,'-ObserverDefaults')
            if($request.use_validated_v20){$childArgs+='-ValidatedV20'}
            $activeChild=Start-Process -FilePath $hostExe -WindowStyle Hidden -WorkingDirectory $repo -ArgumentList $childArgs -RedirectStandardOutput "$childBatch.stdout.log" -RedirectStandardError "$childBatch.stderr.log" -PassThru
            $state.current.runner_pid=$activeChild.Id;Save-OvernightState
            $deadline=(Get-Date).AddMinutes(25)
            while(-not$activeChild.HasExited){
                if(Test-Path "$childBatch/status.json"){
                    $childState=Read-QueueJson "$childBatch/status.json"
                    $state.current.score=$childState.current.score
                    $state.current.game_pid=$childState.current.pid
                    $state.current.child_state=$childState.state
                    Save-OvernightState
                }
                if((Get-Date)-gt$deadline){throw 'Per-map watcher exceeded twenty-five minutes; stop for ownership-safe inspection'}
                Start-Sleep -Seconds 2;$activeChild.Refresh()
            }
            $activeChild=$null
            if(-not(Test-Path "$childBatch/status.json")){throw 'Per-map runner failed before creating status; inspect its stderr'}
            $childState=Read-QueueJson "$childBatch/status.json"
            if(-not$childState.profile_restored){throw 'Per-map profile restoration failed; stop instead of changing a loaded profile'}
            Check-FrozenRuntime
            $passed=$childState.state-eq'complete'-and$childState.results.Count-eq1-and$childState.results[0].result.valid-eq'true'
            $attemptRows+=@{attempt=$attempt;state=$childState.state;directory=$childBatch;failure=$childState.failure}
            if($passed){$success=$childState.results[0];break}
            if($childState.state-ne'stopped_error'){throw 'Unexpected per-map stop; do not continue automatically'}
            $mapFailure=[string]$childState.failure
            if($mapFailure-notmatch'Game error:|Uncontrolled survey population|Invalid match result|Survey game exited early|No survey heartbeat|Map exceeded wall-clock|Missing completed match result'){throw "Non-map failure requires inspection: $mapFailure"}
            $state.state='retrying';Save-OvernightState
        }
        $state.results+=@{map=$map;status=$(if($success){'passed'}else{'failed'});goal=$goal;observer_loadout_restore=$false;result=$(if($success){$success.result}else{$null});directory=$(if($success){$success.directory}else{$null});report_error=$(if($success){$success.report_error}else{$null});attempts=$attemptRows}
        $state.state='between_maps';Save-OvernightState
        foreach($saved in $normalHashes){if((Get-FileHash -LiteralPath $saved.path).Hash-ne$saved.hash){throw 'Normal save changed; stop to preserve the current player session'}}
    }
    if($state.state-ne'stopped_by_request'){
        $state.state=if(@($state.results|Where-Object {$_.status-eq'failed'}).Count){'complete_with_failures'}else{'complete'}
    }
}catch{$state.state='stopped_error';$state.failure=[string]$_}
finally{
    # The active child has its own bounded watchdog/cleanup; never terminate a
    # PowerShell process while it may still own a loaded game profile.
    if($activeChild-and-not$activeChild.HasExited){$state.active_child_left_to_finish=$activeChild.Id}
    if($state.awake_guard){[void][NorthstarSurveyPower]::SetThreadExecutionState([uint32]2147483648);$state.awake_guard=$false}
    $state.finished=(Get-Date).ToString('o');Save-OvernightState
    [ordered]@{state=$state.state;finished=$state.finished;prior_complete=$state.prior_completed.Count;new_complete=@($state.results|Where-Object {$_.status-eq'passed'}).Count;failed=@($state.results|Where-Object {$_.status-eq'failed'}).Count;failure=$state.failure;normal_saves_guarded=$normalHashes.Count}|ConvertTo-Json|Set-Content "$batch/summary.json"
}
