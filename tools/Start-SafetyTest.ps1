param([string]$Profile="$env:USERPROFILE/northstar-crash-audit/map-cycle-test-profile",
    [Parameter(Mandatory)][string]$DllPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Northstar-ModState.ps1"
$repo=Split-Path $PSScriptRoot
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is already running'}
if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Safety harness requires the working isolated profile'}
if((Get-Item "$Profile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'Need matching core'}
$run=Join-Path (Split-Path $repo) ('Notes/candidates/v21-tests/safety-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item $cfg "$run/idle.cfg"
Copy-Item "$Profile/enabledmods.json" "$run/enabledmods-before.json"
Copy-Item $DllPath "$Profile/plugins/bp_ort.dll" -Force
Copy-Item "$repo/BT7274.BotDecisions/*" "$Profile/mods/BT7274.BotDecisions" -Recurse -Force
Copy-Item "$repo/automation/runtime-mods/safety/BT7274.SafetyTest" "$Profile/mods" -Recurse -Force
$enabled=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
foreach($name in @('BT7274.DecisionTest','BT7274.WeaponIntegrationTest','BT7274.CapabilityTest')){Disable-NorthstarMod $enabled $name $Profile}
$enabled|Add-Member -NotePropertyName 'BT7274.SafetyTest' -NotePropertyValue @{'1.0.0'=$true} -Force
$enabled|Add-Member -NotePropertyName 'BT7274.BotDecisions' -NotePropertyValue @{'1.0.0'=$false;'1.1.0'=$true} -Force
$enabled|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
Add-Content $cfg "`nsolo_notes_mode controlled_validation`nbot_telemetry_interval 0.5`n"
$gameDir='C:/Program Files (x86)/Steam/steamapps/common/Titanfall2'
$started=Get-Date
$game=Start-Process "$gameDir/NorthstarLauncher.exe" -WorkingDirectory $gameDir -WindowStyle Hidden -PassThru -ArgumentList "-profile=$Profile",'-bt7274_safety_test','-novid','-windowed','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16 scorelimit 9999 timelimit 30"','+bt7274_safety_test','1','+bt7274_safety_stage','1','+solo_notes_mode','controlled_validation','+mp_gamemode','tdm','+map','mp_eden'
$shell=(Get-Process -Id $PID).Path
$watch=Start-Process $shell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile','-File',"$PSScriptRoot/Watch-SafetyTest.ps1",'-GameProcessId',$game.Id,'-Profile',$Profile,'-RunDirectory',$run,'-Started',$started.ToString('o') -RedirectStandardOutput "$run/watcher.stdout.log" -RedirectStandardError "$run/watcher.stderr.log"
[ordered]@{game_pid=$game.Id;watcher_pid=$watch.Id;profile=$Profile;run=$run;native_sha256=(Get-FileHash $DllPath).Hash;bridge_sha256=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash;started=$started.ToString('o')}|ConvertTo-Json|Set-Content "$repo/target/v21-safety-session.json"
Get-Content "$repo/target/v21-safety-session.json"
