param([Parameter(Mandatory)][string]$RequestPath)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Northstar-ModState.ps1"
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
. "$PSScriptRoot/Read-AwarenessValidation.ps1"
. "$PSScriptRoot/Write-SurveyQueueJson.ps1"
$request=Get-Content $RequestPath -Raw|ConvertFrom-Json
$profile=(Resolve-Path $request.profile).Path;$deadline=[datetime]$request.deadline;$batch=[string]$request.batch
if((Split-Path $profile -Leaf)-ne'map-cycle-test-profile'-or(Get-Date)-ge$deadline){throw 'Invalid profile/deadline'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Game already running'}
if(Test-Path $batch){throw 'Fresh batch directory required'}
$frozen=Read-AwarenessValidation $request.validation $profile
$definition=Get-Content "$repo/automation/awareness-v31-cells.json" -Raw|ConvertFrom-Json
$normalGuard=Get-Content "$($request.backup)/normal-guard.json" -Raw|ConvertFrom-Json
$cfg="$profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
$public="$repo/research/awareness-v31-20261030"
New-Item -ItemType Directory -Path $batch,$public -Force|Out-Null
Copy-Item $RequestPath "$batch/request.json"
$sourceFiles=@(Get-ChildItem "$repo/tools" -Filter '*.mjs' -File)+@(Get-Item "$repo/tools/Run-AwarenessStudy.ps1","$repo/tools/Read-AwarenessValidation.ps1","$repo/automation/awareness-v31-cells.json","$repo/automation/runtime-mods/map-cycle-test-profile/BT7274.MapSurvey/mod/scripts/vscripts/bt7274_map_survey.nut")
$sourceGuard=@($sourceFiles|ForEach-Object{@{path=$_.FullName;hash=(Get-FileHash $_.FullName).Hash}})
$sourceGuard|ConvertTo-Json|Set-Content "$batch/private-source-guard.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');deadline=$deadline.ToString('o');results=@();decisions=@();disabled_cells=@();failure=$null;current=$null;profile_restored=$false;normal_unchanged=$true}
function Save-State{
 $state.updated=(Get-Date).ToString('o');Write-SurveyQueueJson "$batch/status.json" $state
 $safe=[ordered]@{cohort='awareness_v31';state=$state.state;started=$state.started;updated=$state.updated;deadline=$state.deadline;native_sha256=$frozen.native_sha256;source_commit=$request.source_commit;completed=$state.results.Count;current=$(if($state.current){@{map=$state.current.map;cell=$state.current.cell;score=$state.current.score}}else{$null});decisions=$state.decisions;disabled_cells=$state.disabled_cells;normal_unchanged=$state.normal_unchanged;profile_restored=$state.profile_restored;failure_present=[bool]$state.failure;rounds=@($state.results|ForEach-Object{@{map=$_.map;cell=$_.cell;metrics=$_.metrics}});limits='Adaptive exploratory bot-only observer trials; separate cells and native hashes. No human fairness or randomized causal claim. No normal promotion. Raw logs, saves, paths and actor handles remain private.'}
 Write-SurveyQueueJson "$public/status.json" $safe
}
function Check-Normal{foreach($g in $normalGuard){if((Get-FileHash -LiteralPath $g.path).Hash-ne$g.hash){$state.normal_unchanged=$false;throw 'Normal profile changed; stop isolated tests'}}}
function Check-Frozen{
 foreach($g in $sourceGuard){if((Get-FileHash -LiteralPath $g.path).Hash-ne$g.hash){throw 'Frozen source changed'}}
 if((Get-FileHash "$profile/plugins/bp_ort.dll").Hash-ne$frozen.native_sha256-or(Get-FileHash "$profile/Northstar.dll").Hash-ne$frozen.core_sha256){throw 'Frozen native/core changed'}
 foreach($pair in @(@('bridge','BT7274.BotDecisions','bt7274_bot_decisions.nut'),@('self_damage','BT7274.FragSelfDamage','bt7274_frag_self_damage.nut'),@('measurement','BT7274.BotMeasurements','bt7274_bot_measurements.nut'),@('damage_probe','BT7274.FragDamageProbe','bt7274_frag_damage_probe.nut'))){if((Get-FileHash "$profile/mods/$($pair[1])/mod/scripts/vscripts/$($pair[2])").Hash-ne$frozen.($pair[0]+'_sha256')){throw 'Frozen runtime script changed'}}
}
function Settings([string]$Cell){$s=[ordered]@{};foreach($p in $definition.base.PSObject.Properties){$s[$p.Name]=$p.Value};foreach($p in $definition.cells.$Cell.PSObject.Properties){$s[$p.Name]=$p.Value};return $s}
$game=$null;$reader=$null;$log=$null;$awake=$false
try{
 Check-Normal;Check-Frozen
 Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class AwarenessStudyPower{[DllImport("kernel32.dll")]public static extern uint SetThreadExecutionState(uint f);}'
 if([AwarenessStudyPower]::SetThreadExecutionState([uint32]2147483649)-eq0){throw 'Cannot prevent system sleep'};$awake=$true
 $enabled=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
 foreach($name in @('BT7274.SafetyTest','BT7274.DecisionTest','BT7274.CapabilityTest','BT7274.WeaponIntegrationTest','BT7274.RouteProbe','BT7274.FragAwareness','BT7274.FragSelfDamageTest')){Disable-NorthstarMod $enabled $name $profile}
 foreach($name in @('BT7274.MapSurvey','BT7274.BotMeasurements','BT7274.FragSelfDamage')){$enabled|Add-Member -NotePropertyName $name -NotePropertyValue @{'1.0.0'=$true} -Force}
 $enabled|Add-Member -NotePropertyName 'BT7274.FragDamageProbe' -NotePropertyValue @{'0.1.0'=$true} -Force
 $enabled|ConvertTo-Json -Depth 10|Set-Content "$profile/enabledmods.json"
 Copy-Item "$repo/automation/runtime-mods/survey/BT7274.MapSurvey/mod.json" "$profile/mods/BT7274.MapSurvey/mod.json" -Force
 $template=[IO.File]::ReadAllText("$repo/automation/runtime-mods/map-cycle-test-profile/BT7274.MapSurvey/mod/scripts/vscripts/bt7274_map_survey.nut")
 $baseCfg=[IO.File]::ReadAllText("$($request.backup)/map-cycle-test-profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg")
 $gameDir='C:/Program Files (x86)/Steam/steamapps/common/Titanfall2'
 $index=0;$cycle=0
 while((Get-Date).AddMinutes(12)-lt$deadline){
  $trialMaps=if($cycle-lt2){@($request.maps|Select-Object -First 4)}else{@($request.maps)}
  foreach($map in $trialMaps){
   $cells=if($cycle-eq0){@('baseline','memory4')}elseif($cycle-eq1){@('baseline','memory2','memory6','memory4_fov')}else{
    # Choose a repeat candidate by closeness to baseline activity, not maximum kills.
    $base=@($state.results|Where-Object{$_.map-eq$map-and$_.cell-eq'baseline'}|Select-Object -Last 1)
    $choices=@($state.results|Where-Object{$_.map-eq$map-and$_.cell-ne'baseline'-and$_.cell-notin$state.disabled_cells})
    $best='memory4';$cost=[double]::PositiveInfinity
    if($base.Count-and$choices.Count){$b=$base[0].metrics;$bp=($b.score.imc+$b.score.militia)/[Math]::Max(1,$b.duration_s)
     foreach($r in $choices){$m=$r.metrics;$pace=($m.score.imc+$m.score.militia)/[Math]::Max(1,$m.duration_s);$score=[Math]::Abs($pace/[Math]::Max(0.001,$bp)-1)+[Math]::Max(0,$m.low_progress_percent-$b.low_progress_percent)/10;if($score-lt$cost){$cost=$score;$best=$r.cell}}
    }
    $state.decisions+=@{cycle=$cycle;map=$map;repeat_cell=$best;reason='Closest observed control activity plus low-progress penalty; exploratory, no human fairness claim'}
    @('baseline',$best)
   }
   if(($cycle+([array]::IndexOf([object[]]$request.maps,$map)))%2){[array]::Reverse($cells)}
   foreach($cell in $cells){
    if((Get-Date).AddMinutes(12)-ge$deadline){$state.state='stopped_time_budget';break}
    if(Test-Path "$batch/stop-after-current.txt"){$state.state='stopped_by_request';break}
    if($cell-in$state.disabled_cells){continue}
    Check-Normal;Check-Frozen
    if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared'}
    if(!(Get-ChildItem "$gameDir/vpk" -Filter "*_$map.bsp.pak000_dir.vpk" -File)){throw 'Missing map assets'}
    $index++;$dir=Join-Path $batch ('{0:D3}-{1}-{2}'-f$index,$map,$cell);New-Item -ItemType Directory -Path $dir|Out-Null
    $settings=Settings $cell
    $config=$baseCfg+"`nns_auth_allow_insecure 1`nns_allow_spectators 1`nns_should_return_to_lobby 0`nbot_manager_target 17`nbot_manager_max 17`nbt7274_local_loadouts 0`nsolo_notes_mode controlled_validation`nbot_telemetry_interval 1`nbt7274_bot_frag_self_damage_log 1`n"
    foreach($p in $settings.GetEnumerator()){$config+=$definition.convars.($p.Key)+' '+$p.Value+"`n"}
    [IO.File]::WriteAllText($cfg,$config)
    $script=[regex]::Replace($template,'array<string> maps = \[[^\r\n]+\]',('array<string> maps = ["'+$map+'"]'))
    $marker='(?m)^(\s*print\( "MAP_SURVEY_BEGIN[^\r\n]+)$';if([regex]::Matches($script,$marker).Count-ne1){throw 'Survey marker mismatch'}
    $readback='    print("MAP_SURVEY_AWARENESS t="+Time()+" cell='+$cell+'"'
    foreach($key in $settings.Keys){$readback+='+" '+$key+'="+GetConVarFloat("'+$definition.convars.$key+'")'};$readback+=')'
    $script=[regex]::Replace($script,$marker,('$1'+"`n"+$readback));[IO.File]::WriteAllText("$profile/mods/BT7274.MapSurvey/mod/scripts/vscripts/bt7274_map_survey.nut",$script)
    $settings|ConvertTo-Json|Set-Content "$dir/settings.json"
    $began=Get-Date;$state.current=@{map=$map;cell=$cell;directory=$dir;score=$null};$state.state='starting';Save-State
    $game=Start-Process "$gameDir/NorthstarLauncher.exe" -WorkingDirectory $gameDir -WindowStyle Hidden -PassThru -ArgumentList "-profile=$profile",'-novid','-windowed','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides',('"max_players 17 scorelimit '+$request.goal+' timelimit 10"'),'+bt7274_survey_goal',[string]$request.goal,'+bt7274_survey_count','1','+bt7274_survey_index','0','+bt7274_survey_minutes','10','+bt7274_survey_smoke','0','+mp_gamemode','tdm','+map',$map
    $state.current.game_pid=$game.Id;Save-State
    $reader=$null;$log=$null;$done=$false;$result=$false;$lastHeartbeat=Get-Date
    while(!$done){
     Check-Normal
     if(!$log){$log=Get-ChildItem "$profile/logs/nslog*.txt"|Where-Object CreationTime -ge $began.AddSeconds(-2)|Sort-Object CreationTime -Descending|Select-Object -First 1;if($log){$reader=[IO.StreamReader]::new([IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite))}}
     if($reader){while($null-ne($line=$reader.ReadLine())){
      if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_ROSTER_ERROR|BOT_MEASURE_ERROR|BT_FRAG_DAMAGE_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR'){throw "Runtime fault: $line"}
      if($line-match'NorthstarLauncher version:\s+(\S+)' -and $Matches[1]-ne'1.31.14.0'){throw 'Wrong core startup'}
      if($line.Contains('MAP_SURVEY_BEGIN ')){if($line-notmatch'bots=16 imc=8 militia=8 observer_alive=0'){throw 'Wrong observer population'};$state.state='running';$lastHeartbeat=Get-Date}
      if($line.Contains('MAP_SURVEY_SCORE ')){$state.current.score=$line.Substring($line.IndexOf('MAP_SURVEY_SCORE '));$lastHeartbeat=Get-Date}
      if($line.Contains('MAP_SURVEY_RESULT ')){if($line-notmatch'valid=true'){throw 'Invalid round'};$result=$true}
      if($line.Contains('MAP_SURVEY_DONE ')){$done=$true;break}
     }}
     if($done){break}
     $game.Refresh();if($game.HasExited){throw 'Game exited before completed round'}
     if((Get-Date)-ge$deadline-or(Get-Date)-$began-gt[TimeSpan]::FromMinutes(15)-or(Get-Date)-$lastHeartbeat-gt[TimeSpan]::FromMinutes(4)){throw 'Round deadline/heartbeat exceeded'}
     Save-State;Start-Sleep -Seconds 2
    }
    if(!$result){throw 'Missing valid result'}
    $reader.Dispose();$reader=$null;Stop-OwnedSurveyGame -Process $game -Profile $profile;$game=$null
    Copy-Item -LiteralPath $log.FullName -Destination "$dir/raw-session.log";$log=$null
    & node --preserve-symlinks --preserve-symlinks-main "$repo/tools/Review-AwarenessRound.mjs" "$dir/raw-session.log" "$dir/metrics.json" > "$dir/analysis.stdout.log"
    if($LASTEXITCODE-ne0){throw 'Round analysis failed'}
    $m=Get-Content "$dir/metrics.json" -Raw|ConvertFrom-Json
    if($m.error_markers-ne0-or$m.cell-ne$cell-or$m.map-ne$map-or$m.goal-ne$request.goal-or$m.frag_self_scaling.errors-ne0-or$m.awareness.changed_hidden_goal_comparisons-ne0){throw 'Runtime or hidden-goal invariant failed'}
    $state.results+=@{cycle=$cycle;map=$map;cell=$cell;directory=$dir;metrics=$m}
    if($cell-ne'baseline'){
     $base=@($state.results|Where-Object{$_.map-eq$map-and$_.cell-eq'baseline'}|Select-Object -Last 1)
     if($base.Count){$b=$base[0].metrics;$pace=($m.score.imc+$m.score.militia)/[Math]::Max(1,$m.duration_s);$bp=($b.score.imc+$b.score.militia)/[Math]::Max(1,$b.duration_s)
      if(($m.live_pilot_samples-ge500-and$m.low_progress_percent-gt($b.low_progress_percent+5)-and$m.low_progress_percent-gt(1.5*$b.low_progress_percent))-or($m.duration_s-gt300-and$pace-lt($bp*0.35))){$state.disabled_cells+=@($cell);$state.decisions+=@{map=$map;cell=$cell;reason='Operational low-progress or severe activity regression cutoff; not statistical significance'}}
     }
    }
    $state.current=$null;$state.state='between_rounds';Save-State
   }
   if($state.state-like'stopped*'){break}
  }
  if($state.state-like'stopped*'){break};$cycle++
 }
 if($state.state-in@('preparing','between_rounds')){$state.state='stopped_time_budget'}
}catch{$state.state='stopped_error';$state.failure=[string]$_}
finally{
 if($reader){$reader.Dispose()}
 try{Stop-OwnedSurveyGame -Process $game -Profile $profile}catch{$state.state='stopped_error';$state.failure+='; shutdown '+[string]$_}
 if($log-and$state.current){Copy-Item -LiteralPath $log.FullName -Destination "$($state.current.directory)/raw-session.log" -ErrorAction SilentlyContinue}
 if(!(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
  try{
   if((Get-FileHash "$profile/plugins/bp_ort.dll").Hash-ne$frozen.native_sha256){throw 'Do not overwrite changed native'}
   foreach($rel in @('plugins/bp_ort.dll','enabledmods.json','bt7274-candidate.json','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg')){if(Test-Path "$($request.backup)/map-cycle-test-profile/$rel"){Copy-Item "$($request.backup)/map-cycle-test-profile/$rel" "$profile/$rel" -Force}}
   $mods=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
   foreach($name in @('BT7274.SafetyTest','BT7274.MapSurvey','BT7274.BotMeasurements','BT7274.FragDamageProbe','BT7274.FragAwareness','BT7274.FragSelfDamageTest','BT7274.FragSelfDamage')){Disable-NorthstarMod $mods $name $profile}
   $mods|ConvertTo-Json -Depth 10|Set-Content "$profile/enabledmods.json";$state.profile_restored=$true
  }catch{$state.state='stopped_error';$state.failure+='; restore '+[string]$_}
 }else{$state.cleanup_pending=$true}
 if($awake){[void][AwarenessStudyPower]::SetThreadExecutionState([uint32]2147483648)}
 try{Check-Normal}catch{$state.failure+='; normal guard '+[string]$_}
 $state.finished=(Get-Date).ToString('o');Save-State
}
