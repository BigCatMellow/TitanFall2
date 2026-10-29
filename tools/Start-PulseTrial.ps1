param([Parameter(Mandatory)][string]$Profile,[Parameter(Mandatory)][string]$DllPath,[switch]$WithoutPowerCell)
$ErrorActionPreference='Stop';$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Northstar-ModState.ps1"
if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Isolated profile only'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Game active'}
$run=Join-Path (Split-Path $repo) ('Notes/candidates/integration-v28/pulse-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory $run -Force|Out-Null
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item $cfg "$run/server.cfg";Copy-Item "$Profile/enabledmods.json" "$run/enabledmods.json"
Copy-Item "$Profile/mods/BT7274.TacticalRecharge" $run -Recurse
Copy-Item "$repo/BT7274.TacticalRecharge/*" "$Profile/mods/BT7274.TacticalRecharge" -Recurse -Force
Copy-Item "$repo/automation/runtime-mods/pulse-trial/BT7274.PulseTrial" "$Profile/mods" -Recurse -Force
Copy-Item "$Profile/mods/BT7274.PulseTrial/mod/scripts/vscripts/bt7274_pulse_trial.nut" "$run/probe.nut"
Copy-Item $DllPath "$Profile/plugins/bp_ort.dll" -Force
$mods=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
foreach($name in @('BT7274.SafetyTest','BT7274.MapSurvey','BT7274.RouteProbe','BT7274.BotMeasurements','BT7274.FragDamageProbe','BT7274.TacticalRecharge')){Disable-NorthstarMod $mods $name $Profile}
$mods|Add-Member -NotePropertyName 'BT7274.TacticalRecharge' -NotePropertyValue @{'1.0.0'=$false;'1.1.0'=$true} -Force
$mods|Add-Member -NotePropertyName 'BT7274.PulseTrial' -NotePropertyValue @{'0.1.0'=$true} -Force
$mods|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
Add-Content $cfg "`nns_auth_allow_insecure 1`nbt7274_pulse_trial 1`nbt7274_local_loadouts 0`nsolo_notes_mode controlled_validation`nbot_manager_target 16`nbot_manager_max 16`nbot_eden_route_repair 1`nbot_nearest_pursuit 0`nbot_stall_target_recovery 0`nbot_frag_safety 0`nbot_low_clearance_approach 0`nbot_corner_height_trial 0"
Add-Content $cfg ("bt7274_pulse_power_cell "+[int](!$WithoutPowerCell))
$gameDir='C:/Program Files (x86)/Steam/steamapps/common/Titanfall2';$started=Get-Date
$game=Start-Process "$gameDir/NorthstarLauncher.exe" -WorkingDirectory $gameDir -WindowStyle Hidden -PassThru -ArgumentList "-profile=$Profile",'-novid','-windowed','-ip','127.0.0.1','-port','37025','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16 scorelimit 9999 timelimit 15"','+mp_gamemode','tdm','+map','mp_complex3'
$shell=(Get-Process -Id $PID).Path
$watchArgs=@('-NoProfile','-File',"$PSScriptRoot/Watch-PulseTrial.ps1",'-Profile',$Profile,'-RunDirectory',$run,'-GameProcessId',$game.Id,'-Started',$started.ToString('o'))
if($WithoutPowerCell){$watchArgs+='-WithoutPowerCell'}
$watch=Start-Process $shell -WindowStyle Hidden -PassThru -ArgumentList $watchArgs -RedirectStandardOutput "$run/watcher.stdout.log" -RedirectStandardError "$run/watcher.stderr.log"
[ordered]@{run=$run;game_pid=$game.Id;watcher_pid=$watch.Id;profile=$Profile;native_sha256=(Get-FileHash $DllPath).Hash;started=$started.ToString('o')}|ConvertTo-Json|Set-Content "$repo/target/v28-pulse-session.json"
Get-Content "$repo/target/v28-pulse-session.json"
