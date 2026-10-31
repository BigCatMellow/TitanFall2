param([string]$Profile="$env:USERPROFILE/northstar-crash-audit/map-cycle-test-profile")
$ErrorActionPreference='Stop'
function Get-ContentHash([string]$Path){$h=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($Path);try{[BitConverter]::ToString($h.ComputeHash($f)).Replace('-','')}finally{$f.Dispose();$h.Dispose()}}
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Northstar-ModState.ps1"
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Isolated profile only'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Game already running'}
$run=Join-Path (Split-Path $repo) ('Notes/candidates/frag-self-damage/test-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item $cfg "$run/config-before.cfg"
Copy-Item "$Profile/enabledmods.json" "$run/enabled-before.json"
if(Test-Path "$Profile/save_data"){Copy-Item "$Profile/save_data" "$run/current-save-backup" -Recurse}
$normal=Join-Path (Split-Path $repo) 'local-test-profile'
$guard=@('enabledmods.json','plugins/bp_ort.dll','mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg'|ForEach-Object{@{path=(Join-Path $normal $_);hash=(Get-ContentHash (Join-Path $normal $_))}})
$guard|ConvertTo-Json|Set-Content "$run/normal-guard.json"
$state=[ordered]@{state='preparing';run=$run;started=(Get-Date).ToString('o');matrices=@();cases=0;combat=@();lobby=$false;failure=$null;cleanup=$false;normal_unchanged=$false}
function Save-State {$state.updated=(Get-Date).ToString('o');$state|ConvertTo-Json -Depth 8|Set-Content "$run/status.json"}
[ordered]@{run=$run}|ConvertTo-Json|Set-Content "$repo/target/frag-self-test-session.json"
$game=$null;$reader=$null;$log=$null
try{
 Copy-Item "$repo/BT7274.FragSelfDamage" "$Profile/mods" -Recurse -Force
 Copy-Item "$repo/automation/runtime-mods/frag-self-test/BT7274.FragSelfDamageTest" "$Profile/mods" -Recurse -Force
 $enabled=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
 foreach($name in @('BT7274.SafetyTest','BT7274.DecisionTest','BT7274.CapabilityTest','BT7274.WeaponIntegrationTest','BT7274.MapSurvey','BT7274.RouteProbe')){Disable-NorthstarMod $enabled $name $Profile}
 foreach($name in @('BT7274.FragSelfDamage','BT7274.FragSelfDamageTest')){$enabled|Add-Member -NotePropertyName $name -NotePropertyValue @{'1.0.0'=$true} -Force}
 $enabled|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
 Add-Content $cfg "`nsolo_notes_mode controlled_validation`nbt7274_frag_self_test 1`nbt7274_frag_self_test_stage 1`nbt7274_bot_frag_self_damage 1`nbt7274_bot_frag_self_damage_scale 0.25`nbt7274_bot_frag_self_damage_log 1`nns_auth_allow_insecure 1`n"
 $started=Get-Date
 $gameDir='C:/Program Files (x86)/Steam/steamapps/common/Titanfall2'
 $game=Start-Process "$gameDir/NorthstarLauncher.exe" -WorkingDirectory $gameDir -WindowStyle Hidden -PassThru -ArgumentList "-profile=$Profile",'-bt7274_frag_self_test','-novid','-windowed','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16 scorelimit 9999 timelimit 30"','+bt7274_frag_self_test','1','+bt7274_frag_self_test_stage','1','+mp_gamemode','tdm','+map','mp_drydock'
 $state.game_pid=$game.Id;$state.state='starting';Save-State
 while((Get-Date)-$started-lt[TimeSpan]::FromMinutes(7)){
  if(!$log){$log=Get-ChildItem "$Profile/logs/nslog*.txt"|Where-Object CreationTime -ge $started.AddSeconds(-2)|Sort-Object CreationTime -Descending|Select-Object -First 1;if($log){$reader=[IO.StreamReader]::new([IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite))}}
  if($reader){while($null-ne($line=$reader.ReadLine())){
   if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|FRAG_SELF_TEST_FAILED|WNOTE_ERROR|BOT_ROSTER_ERROR'){throw "Runtime check failed: $line"}
   if($line-match'FRAG_SELF_TEST_CASE '){$state.cases++}
   if($line-match'FRAG_SELF_TEST_MATRIX_PASS name=(\S+)'){$state.matrices+=$Matches[1];$state.state='running'}
   if($line-match'FRAG_SELF_TEST_COMBAT_PASS map=(\S+)'){$state.combat+=$Matches[1]}
   if($line.Contains('FRAG_SELF_TEST_LOBBY')){$state.lobby=$true}
   if($line.Contains('FRAG_SELF_TEST_DONE')){$state.state='passed';break}
  }}
  if($state.state-eq'passed'){break}
  $game.Refresh();if($game.HasExited){throw 'Owned game exited before completion'}
  Save-State;Start-Sleep -Seconds 1
 }
 if($state.state-ne'passed'-or$state.matrices.Count-ne4-or$state.cases-ne52-or!$state.lobby-or($state.combat-join',')-ne'mp_drydock,mp_glitch'){throw 'Incomplete matrix/lifecycle'}
}catch{$state.state='failed';$state.failure=[string]$_}
finally{
 if($reader){$reader.Dispose()}
 try{Stop-OwnedSurveyGame -Process $game -Profile $Profile}catch{$state.failure+='; cleanup '+[string]$_;$state.state='failed'}
 if($log){Copy-Item -LiteralPath $log.FullName -Destination "$run/raw-session.log"}
 Copy-Item "$run/config-before.cfg" $cfg -Force
 $enabled=Get-Content "$run/enabled-before.json" -Raw|ConvertFrom-Json
 foreach($name in @('BT7274.FragSelfDamage','BT7274.FragSelfDamageTest')){Disable-NorthstarMod $enabled $name $Profile}
 $enabled|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
 $state.normal_unchanged=$true
 foreach($g in $guard){if((Get-ContentHash $g.path)-ne$g.hash){$state.normal_unchanged=$false;$state.state='failed'}}
 $state.cleanup=(!$game-or$game.HasExited)
 Save-State
}
Get-Content "$run/status.json"
