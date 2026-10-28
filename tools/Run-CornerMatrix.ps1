param([Parameter(Mandatory)][string]$RequestPath)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Read-CornerValidation.ps1"
. "$PSScriptRoot/Read-SurveyQueueJson.ps1"
$request=Get-Content $RequestPath -Raw|ConvertFrom-Json
$profile=(Resolve-Path $request.profile).Path
$batch=[string]$request.batch
$deadline=[datetime]$request.deadline
$frozen=Read-CornerValidation $request.validation $profile
if(Test-Path $batch){throw 'Preserve an existing matrix batch'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game is running'}
$rollback=(Resolve-Path $request.rollback).Path
if((Get-FileHash "$rollback/plugins/bp_ort.dll").Hash-ne'3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89'){throw 'Rollback must contain validated v20'}
New-Item -ItemType Directory -Path $batch|Out-Null
Copy-Item $RequestPath "$batch/request.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');planned=$request.rounds.Count;results=@();skipped=@();guard_stopped=$false;current=$null;failure=$null;profile_restored=$false}
$normal=@(Get-ChildItem "$($request.normal_profile)/save_data" -Recurse -File|ForEach-Object {@{path=$_.FullName;hash=(Get-FileHash $_.FullName).Hash}})
foreach($rel in @('plugins/bp_ort.dll','enabledmods.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')){
    $p=Join-Path $request.normal_profile $rel;$normal+=@{path=$p;hash=(Get-FileHash $p).Hash}
}
$normal|ConvertTo-Json|Set-Content "$batch/private-normal-guard.json"
$public="$repo/research/corner-height-v22-20261028"
New-Item -ItemType Directory -Path $public -Force|Out-Null
function Save-Matrix {
    $state.updated=(Get-Date).ToString('o')
    $state|ConvertTo-Json -Depth 14|Set-Content "$batch/status.tmp"
    Move-Item -LiteralPath "$batch/status.tmp" -Destination "$batch/status.json" -Force
    $rows=@($state.results|ForEach-Object {@{map=$_.map;repeat=$_.repeat;guard=$_.guard;metrics=$_.metrics}})
    [ordered]@{state=$state.state;updated=$state.updated;source_commit=$request.source_commit;profile_restored=$state.profile_restored;native_sha256=$frozen.dll_sha256;bridge_sha256=$frozen.bridge_sha256;core_sha256=$frozen.core_sha256;goal=$request.goal;planned=$state.planned;completed=$rows.Count;guard_stopped=$state.guard_stopped;skipped=$state.skipped;rounds=$rows;limits='Matched 50-point bot-only rounds, same native build, one corner switch. Reversed order/repeats limit order effects but do not establish causal improvement. Native safety switches stay off. Operational regression cutoff skips subsequent guard-on rounds while baseline variety continues; it is not a statistical significance test.'}|ConvertTo-Json -Depth 14|Set-Content "$public/matrix-results.json"
}
function Check-Normal {
    foreach($saved in $normal){if((Get-FileHash $saved.path).Hash-ne$saved.hash){throw 'Normal files/saves changed; stop for current player activity'}}
}
$child=$null;$awake=$false
try{
    Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public static class CornerMatrixPower {
 [DllImport("kernel32.dll")]public static extern uint SetThreadExecutionState(uint flags);
}
'@
    if([CornerMatrixPower]::SetThreadExecutionState([uint32]2147483649)-eq0){throw 'Could not establish process-scoped sleep guard'};$awake=$true
    $hostExe=(Get-Process -Id $PID).Path
    $index=0
    foreach($round in $request.rounds){
        if((Get-Date).AddMinutes(20)-gt$deadline){$state.state='stopped_time_budget';break}
        if(Test-Path "$batch/stop-after-current.txt"){$state.state='stopped_by_request';break}
        if($state.guard_stopped-and[int]$round.guard-eq1){
            $state.skipped+=@{map=$round.map;repeat=$round.repeat;guard=1;reason='Prior operational regression cutoff'};Save-Matrix;continue
        }
        Check-Normal
        $check=Read-CornerValidation $request.validation $profile
        if($check.dll_sha256-ne$frozen.dll_sha256-or$check.bridge_sha256-ne$frozen.bridge_sha256-or$check.core_sha256-ne$frozen.core_sha256){throw 'Frozen runtime changed'}
        if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared; do not replace it'}
        $index++;$dir=Join-Path $batch ('{0:D2}-{1}-r{2}-guard{3}'-f$index,$round.map,$round.repeat,$round.guard)
        $state.state='running';$state.current=@{index=$index;map=$round.map;guard=$round.guard;repeat=$round.repeat;directory=$dir;score=$null};Save-Matrix
        $childArgs=@('-NoProfile','-File',"$repo/tools/Run-CandidateSurvey.ps1",'-BatchDirectory',$dir,'-ValidationDirectory',[string]$request.validation,'-ReadinessRetestDirectory',[string]$request.validation,'-TestProfile',$profile,'-Goal',[string]$request.goal,'-MapNames',[string]$round.map,'-ObserverDefaults','-NavigationV22','-CornerGuard',[string]$round.guard)
        $child=Start-Process $hostExe -WindowStyle Hidden -WorkingDirectory $repo -PassThru -ArgumentList $childArgs -RedirectStandardOutput "$dir.stdout.log" -RedirectStandardError "$dir.stderr.log"
        $childDeadline=(Get-Date).AddMinutes(25)
        while(-not$child.HasExited){
            if(Test-Path "$dir/status.json"){
                $c=Read-SurveyQueueJson "$dir/status.json"
                $state.current.child_state=$c.state;$state.current.score=$c.current.score;$state.current.game_pid=$c.current.pid
                Save-Matrix
            }
            if((Get-Date)-gt$childDeadline){throw 'Child exceeded its bounded watchdog; inspect ownership before cleanup'}
            Start-Sleep -Seconds 2;$child.Refresh()
        }
        $child=$null
        $c=Read-SurveyQueueJson "$dir/status.json"
        if($c.state-ne'complete'-or-not$c.profile_restored-or$c.results.Count-ne1-or$c.results[0].result.valid-ne'true'){throw "Child failed: $($c.failure)"}
        $raw=Join-Path $c.results[0].directory 'raw-session.log'
        & node --preserve-symlinks --preserve-symlinks-main "$repo/tools/Review-CornerRound.mjs" --log $raw --out "$dir/metrics.json" > "$dir/analysis.stdout.log"
        if($LASTEXITCODE-ne0){throw 'Round analysis failed; retain the raw data'}
        $metrics=Get-Content "$dir/metrics.json" -Raw|ConvertFrom-Json
        if($metrics.error_markers-ne0-or$metrics.corner_guard-ne[int]$round.guard-or$metrics.map-ne$round.map-or$metrics.goal-ne[int]$request.goal){throw 'Round error/variant/goal mismatch'}
        $state.results+=@{map=$round.map;repeat=$round.repeat;guard=[int]$round.guard;directory=$dir;metrics=$metrics};$state.state='between_rounds';Save-Matrix
        Check-Normal
        $pair=@($state.results|Where-Object {$_.map-eq$round.map-and$_.repeat-eq$round.repeat})
        if($pair.Count-eq2){
            $off=($pair|Where-Object guard -eq 0).metrics;$on=($pair|Where-Object guard -eq 1).metrics
            if($off.live_pilot_samples-ge500-and$on.live_pilot_samples-ge500-and$on.low_progress_percent-gt($off.low_progress_percent+5)-and$on.low_progress_percent-gt(1.5*$off.low_progress_percent)){
                $state.guard_stopped=$true
                $state.guard_stop_reason='Operational cutoff: matched guard round exceeded baseline by >5 percentage points and >50%; not a causal significance claim. Continue baseline variety only.'
                Save-Matrix
            }
        }
    }
    if($state.state-in@('preparing','between_rounds')){$state.state=if($state.guard_stopped){'complete_baseline_only_after_guard_stop'}else{'complete'}}
}catch{$state.state='stopped_error';$state.failure=[string]$_}
finally{
    if($awake){[void][CornerMatrixPower]::SetThreadExecutionState([uint32]2147483648)}
    $childAlive=$child-and-not$child.HasExited
    if($childAlive){$state.active_child_left_to_finish=$child.Id}
    if(-not$childAlive-and-not(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)-and(Get-FileHash "$profile/plugins/bp_ort.dll").Hash-eq$frozen.dll_sha256){
        try{
            foreach($rel in @('plugins/bp_ort.dll','enabledmods.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')){Copy-Item "$rollback/$rel" "$profile/$rel" -Force}
            Copy-Item "$rollback/mods/BT7274.BotDecisions/*" "$profile/mods/BT7274.BotDecisions" -Recurse -Force
            $state.profile_restored=$true
        }catch{$state.state='stopped_error';$state.failure+='; restore: '+[string]$_}
    }
    $state.finished=(Get-Date).ToString('o');Save-Matrix
}
