param([Parameter(Mandatory)][string]$RequestPath)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Read-TuningValidation.ps1"
. "$PSScriptRoot/Read-SurveyQueueJson.ps1"
. "$PSScriptRoot/Write-SurveyQueueJson.ps1"
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
. "$PSScriptRoot/Northstar-ModState.ps1"
$request=Get-Content $RequestPath -Raw|ConvertFrom-Json
$profile=(Resolve-Path $request.profile).Path;$batch=[string]$request.batch;$deadline=[datetime]$request.deadline
$public=Join-Path $repo 'research/tuning-v29-20261029'
if((Get-Date)-ge$deadline){throw 'Deadline passed'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Game already running'}
if(Test-Path $batch){throw 'Preserve previous batch'}
$frozen=Read-TuningValidation $request.validation $profile
New-Item -ItemType Directory $batch,$public -Force|Out-Null
Copy-Item $RequestPath "$batch/request.json"
$normalGuard=Get-Content "$($request.backup)/normal-guard.json" -Raw|ConvertFrom-Json
$sourceFiles=@('tools/Run-CandidateSurvey.ps1','tools/Review-TuningRound.mjs','tools/Review-RouteStudy.mjs','tools/Analyze-BotAITrial.mjs','tools/Analyze-FragLifecycle.mjs','tools/Compare-FragNotebook.mjs','tools/Integration-Cells.ps1','tools/Read-TuningValidation.ps1','automation/tuning-v29-cells.json','automation/runtime-mods/map-cycle-test-profile/BT7274.MapSurvey/mod/scripts/vscripts/bt7274_map_survey.nut')
$sourceFiles+=@(Get-ChildItem "$repo/tools" -Filter '*.mjs' -File|ForEach-Object {'tools/'+$_.Name})
$sourceFiles=@($sourceFiles|Select-Object -Unique)
$sourceGuard=@($sourceFiles|ForEach-Object{@{path=(Join-Path $repo $_);hash=(Get-FileHash (Join-Path $repo $_)).Hash}})
$sourceGuard|ConvertTo-Json|Set-Content "$batch/private-source-guard.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');deadline=$deadline.ToString('o');results=@();failures=@();skipped=@();disabled_cells=@();current=$null;normal_unchanged=$true;profile_restored=$false;failure=$null}
function Save-State {
 $state.updated=(Get-Date).ToString('o');Write-SurveyQueueJson "$batch/status.json" $state
 $safe=@($state.results|ForEach-Object{@{map=$_.map;cell=$_.cell;repeat=$_.repeat;metrics=$_.metrics}})
 $summary=[ordered]@{schema_version=1;cohort='tuning_v29';state=$state.state;started=$state.started;updated=$state.updated;deadline=$state.deadline;completed=$safe.Count;planned=$request.rounds.Count;failed_attempts=$state.failures.Count;disabled_cells=$state.disabled_cells;normal_unchanged=$state.normal_unchanged;profile_restored=$state.profile_restored;failure_present=[bool]$state.failure;native_sha256=$frozen.dll_sha256;source_commit=$request.source_commit;goal=$request.goal;rounds=$safe;limits='Frozen integrated native, bot-only observer cohort. Cells isolated by explicit readbacks; no randomized human difficulty claim or automatic promotion. Repeated samples overlap. Diagnostics/requests are not confirmed movement success or casts. Raw logs, paths, saves and actor/projectile identifiers remain private. Operational cell stopping is not statistical significance.'}
 Write-SurveyQueueJson "$public/status.json" $summary
}
function Check-Normal {
 foreach($g in $normalGuard){if((Get-FileHash -LiteralPath $g.path).Hash-ne$g.hash){$state.normal_unchanged=$false;throw 'Normal profile activity/change; stop isolated work'}}
}
function Check-Frozen {
 foreach($g in $sourceGuard){if((Get-FileHash -LiteralPath $g.path).Hash-ne$g.hash){throw 'Frozen analysis/harness source changed'}}
 $check=Read-TuningValidation $request.validation $profile
 foreach($f in @('dll_sha256','core_sha256','bridge_sha256','measurement_sha256','damage_probe_sha256','awareness_sha256')){if($check.$f-ne$frozen.$f){throw 'Frozen runtime changed'}}
}
function Check-Regression {
 foreach($r in $state.results){
  if($r.cell-in@('baseline','nearest_baseline')){continue}
  $base=if($r.cell-eq'nearest'){'nearest_baseline'}else{'baseline'}
  $off=@($state.results|Where-Object{$_.map-eq$r.map-and$_.repeat-eq$r.repeat-and$_.cell-eq$base})
  if($off.Count-ne1){continue};$a=$off[0].metrics;$b=$r.metrics
  if($a.live_pilot_samples-ge500-and$b.live_pilot_samples-ge500-and$null-ne$a.low_progress_percent-and$null-ne$b.low_progress_percent-and$b.low_progress_percent-gt($a.low_progress_percent+5)-and$b.low_progress_percent-gt(1.5*$a.low_progress_percent)){
   if($r.cell-notin$state.disabled_cells){$state.disabled_cells+=@($r.cell)}
  }
 }
}
$child=$null;$awake=$false;$dir=$null
try{
 Check-Normal;Check-Frozen
 Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class TuningStudyPower{[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);}'
 if([TuningStudyPower]::SetThreadExecutionState([uint32]2147483649)-eq0){throw 'Cannot prevent system sleep'};$awake=$true
 $hostExe=(Get-Process -Id $PID).Path;$index=0
 foreach($round in $request.rounds){
  if((Get-Date).AddMinutes(8)-gt$deadline){$state.state='stopped_time_budget';break}
  if(Test-Path "$batch/stop-after-current.txt"){$state.state='stopped_by_request';break}
  if($round.cell-in$state.disabled_cells-or($round.cell-eq'combined'-and@($state.disabled_cells|Where-Object{$_-in@('escape','clearance')}).Count)){$state.skipped+=@{map=$round.map;cell=$round.cell;reason='Operational cell regression cutoff'};Save-State;continue}
  Check-Normal;Check-Frozen
  if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared'}
  $index++;$dir=Join-Path $batch ('{0:D2}-{1}-r{2}-{3}'-f$index,$round.map,$round.repeat,$round.cell)
  $state.state='running';$state.current=@{map=$round.map;cell=$round.cell;repeat=$round.repeat;directory=$dir;game_pid=$null;score=$null};Save-State
  $args=@('-NoProfile','-File',"$repo/tools/Run-CandidateSurvey.ps1",'-BatchDirectory',$dir,'-ValidationDirectory',[string]$request.validation,'-ReadinessRetestDirectory',[string]$request.validation,'-TestProfile',$profile,'-Goal',[string]$request.goal,'-MapNames',[string]$round.map,'-ObserverDefaults','-IntegrationV28','-TuningV29','-IntegrationCell',[string]$round.cell)
  $child=Start-Process $hostExe -WindowStyle Hidden -WorkingDirectory $repo -PassThru -ArgumentList $args -RedirectStandardOutput "$dir.stdout.log" -RedirectStandardError "$dir.stderr.log"
  $childDeadline=(Get-Date).AddMinutes(22)
  while(-not$child.HasExited){
   Check-Normal
   if(Test-Path "$dir/status.json"){
    $c=Read-SurveyQueueJson "$dir/status.json";$state.current.child_state=$c.state;$state.current.game_pid=$c.current.pid;$state.current.score=$c.current.score;Save-State
    if((Get-Date)-ge$deadline-and$c.current.pid){$owned=Get-Process -Id $c.current.pid -ErrorAction SilentlyContinue;if($owned){Stop-OwnedSurveyGame -Process $owned -Profile $profile};$state.deadline_stop=$true}
   }
   if((Get-Date)-gt$childDeadline){throw 'Child watchdog exceeded'}
   Start-Sleep -Seconds 2;$child.Refresh()
  }
  $child=$null;$c=Read-SurveyQueueJson "$dir/status.json"
  if($c.state-ne'complete'-or!$c.profile_restored-or$c.results.Count-ne1){
   $state.failures+=@{map=$round.map;cell=$round.cell;reason=$c.failure;directory=$dir}
   if($state.deadline_stop){$state.state='stopped_time_budget';break}
   throw 'Isolated round failed; retain evidence and stop instead of retrying blindly'
  }
  $raw=Join-Path $c.results[0].directory 'raw-session.log'
  & node --preserve-symlinks --preserve-symlinks-main "$repo/tools/Review-TuningRound.mjs" --log $raw --out "$dir/metrics.json" > "$dir/analysis.stdout.log"
  if($LASTEXITCODE-ne0){throw 'Integration analysis failed'}
  $m=Get-Content "$dir/metrics.json" -Raw|ConvertFrom-Json
  if($m.error_markers-ne0-or$m.cell-ne$round.cell-or$m.map-ne$round.map-or$m.goal-ne$request.goal){throw 'Integration metrics mismatch'}
  $state.results+=@{map=$round.map;cell=$round.cell;repeat=$round.repeat;directory=$dir;metrics=$m};Check-Regression
  $state.state='between_rounds';Save-State
 }
 if($state.state-in@('preparing','between_rounds')){$state.state='complete'}
}catch{$state.state='stopped_error';$state.failure=[string]$_}
finally{
 if($child-and-not$child.HasExited){
  try{if($dir-and(Test-Path "$dir/status.json")){$c=Read-SurveyQueueJson "$dir/status.json";if($c.current.pid){$owned=Get-Process -Id $c.current.pid -ErrorAction SilentlyContinue;if($owned){Stop-OwnedSurveyGame -Process $owned -Profile $profile}}};[void]$child.WaitForExit(15000)}catch{$state.failure+='; child cleanup: '+[string]$_}
 }
 if($awake){[void][TuningStudyPower]::SetThreadExecutionState([uint32]2147483648)}
 $childAlive=$child-and-not$child.HasExited
 if(!$childAlive-and!(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
  try{
   if((Get-FileHash "$profile/plugins/bp_ort.dll").Hash-ne$frozen.dll_sha256){throw 'Do not overwrite changed native'}
   $rollback=Join-Path $request.backup 'map-cycle-test-profile'
   foreach($rel in @('plugins/bp_ort.dll','enabledmods.json','bt7274-candidate.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')){if(Test-Path "$rollback/$rel"){Copy-Item "$rollback/$rel" "$profile/$rel" -Force}}
   if(Test-Path "$rollback/mods/BT7274.TacticalRecharge"){Copy-Item "$rollback/mods/BT7274.TacticalRecharge/*" "$profile/mods/BT7274.TacticalRecharge" -Recurse -Force}
   $mods=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
   foreach($name in @('BT7274.SafetyTest','BT7274.MapSurvey','BT7274.RouteProbe','BT7274.BotMeasurements','BT7274.FragDamageProbe','BT7274.PulseTrial','BT7274.FragAwareness')){Disable-NorthstarMod $mods $name $profile}
   $mods|ConvertTo-Json -Depth 10|Set-Content "$profile/enabledmods.json";$state.profile_restored=$true
  }catch{$state.state='stopped_error';$state.failure+='; restore: '+[string]$_}
 }else{$state.cleanup_pending=$true}
 try{Check-Normal}catch{$state.failure+='; guard: '+[string]$_}
 $state.finished=(Get-Date).ToString('o');Save-State
}
