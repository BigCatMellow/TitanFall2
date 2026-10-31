param([Parameter(Mandatory)][string]$Backup,[Parameter(Mandatory)][string]$PriorValidation,[Parameter(Mandatory)][string]$Deadline,[Parameter(Mandatory)][string]$SourceCommit)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
$profile=(Resolve-Path "$repo/../map-cycle-test-profile").Path
$receipt="$repo/target/v31-active-session.json"
$state=[ordered]@{state='waiting_initial_lifecycle';deadline=$Deadline;backup=$Backup;validation=$null;request=$null;batch=$null;failure=$null}
function Save{$state.updated=(Get-Date).ToString('o');$state|ConvertTo-Json -Depth 6|Set-Content $receipt}
try{
 Save;$until=(Get-Date).AddMinutes(5)
 while((Get-Content "$PriorValidation/progress.json" -Raw|ConvertFrom-Json).state-notin@('passed','failed')){if((Get-Date)-gt$until){throw 'Initial lifecycle timeout'};Start-Sleep -Seconds 2}
 $old=Get-Content "$PriorValidation/progress.json" -Raw|ConvertFrom-Json;if($old.state-ne'passed'){throw 'Initial lifecycle failed'}
 $state.state='final_lifecycle';Save
 & "$repo/tools/Start-SafetyTest.ps1" -Profile $profile -DllPath "$repo/target/v31b-candidate.dll" -Map mp_glitch -NextMap mp_drydock -NavigationTrial -IntegrationTrial -Measurements -AwarenessTrial > "$repo/target/v31b-smoke-start.txt"
 $session=Get-Content "$repo/target/v21-safety-session.json" -Raw|ConvertFrom-Json
 $session|ConvertTo-Json|Set-Content "$repo/target/v31b-smoke-session.json";$state.validation=$session.run;Save
 $until=(Get-Date).AddMinutes(15)
 while(!(Test-Path "$($session.run)/progress.json")){if((Get-Date)-gt$until){throw 'No final lifecycle status'};Start-Sleep -Seconds 2}
 while((Get-Content "$($session.run)/progress.json" -Raw|ConvertFrom-Json).state-notin@('passed','failed')){if((Get-Date)-gt$until){throw 'Final lifecycle timeout'};Start-Sleep -Seconds 2}
 . "$repo/tools/Read-AwarenessValidation.ps1"
 $validated=Read-AwarenessValidation $session.run $profile
 $state.state='survey';$state.batch=Join-Path (Split-Path $repo) ('Notes/candidates/awareness-v31/adaptive-'+(Get-Date -Format yyyyMMdd-HHmmss));$state.request="$repo/target/v31-study-request.json"
 $commit=$SourceCommit
 [ordered]@{profile=$profile;deadline=$Deadline;backup=$Backup;batch=$state.batch;validation=$session.run;source_commit=[string]$commit;goal=50;maps=@('mp_glitch','mp_drydock','mp_wargames','mp_complex','mp_relic02','mp_colony02','mp_angel_city','mp_forwardbase_kodai')}|ConvertTo-Json|Set-Content $state.request
 $validated|ConvertTo-Json|Set-Content "$repo/research/awareness-v31-20261030/validation.json"
 Save
 & "$repo/tools/Run-AwarenessStudy.ps1" -RequestPath $state.request
 $state.state='finished';Save
}catch{
 $state.state='failed';$state.failure=[string]$_;Save
 # Watcher normally owns shutdown. Never kill an unrelated game or restore saves.
 if(!(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
  . "$repo/tools/Northstar-ModState.ps1"
  foreach($rel in @('plugins/bp_ort.dll','enabledmods.json','bt7274-candidate.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')){if(Test-Path "$Backup/map-cycle-test-profile/$rel"){Copy-Item "$Backup/map-cycle-test-profile/$rel" "$profile/$rel" -Force}}
  $e=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json;foreach($n in @('BT7274.SafetyTest','BT7274.MapSurvey','BT7274.BotMeasurements','BT7274.FragDamageProbe','BT7274.FragAwareness','BT7274.FragSelfDamage')){Disable-NorthstarMod $e $n $profile};$e|ConvertTo-Json -Depth 10|Set-Content "$profile/enabledmods.json"
 }
}
