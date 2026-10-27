param([Parameter(Mandatory)][string]$CompatibilitySession)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Northstar-ModState.ps1"
$previous=Get-Content -LiteralPath $CompatibilitySession -Raw|ConvertFrom-Json
$deadline=(Get-Date).AddMinutes(10)
do{
    $result=Get-Content "$($previous.run)/progress.json" -Raw|ConvertFrom-Json
    if($result.state-eq'failed'){throw ('Compatibility suite failed: '+$result.failure)}
    if($result.state-eq'passed'){break}
    if((Get-Date)-gt$deadline){throw 'Compatibility suite did not finish'}
    Start-Sleep -Seconds 1
}while($true)
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is still running'}
$profile=$previous.profile;$repo=Split-Path $PSScriptRoot
if((Get-FileHash "$profile/plugins/bp_ort.dll").Hash-ne$previous.dll_sha256){throw 'Candidate changed after compatibility run'}
$run=Join-Path (Split-Path $repo) ('Notes/candidates/v20-tests/capability-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $run|Out-Null
$cfg="$profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item $cfg "$run/idle.cfg"
Copy-Item "$profile/enabledmods.json" "$run/enabledmods-before.json"
Copy-Item "$repo/automation/runtime-mods/capability/BT7274.CapabilityTest/*" "$profile/mods/BT7274.CapabilityTest" -Recurse -Force
$e=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
foreach($name in @('BT7274.DecisionTest','BT7274.WeaponIntegrationTest')){Disable-NorthstarMod $e $name $profile}
$e|Add-Member -NotePropertyName 'BT7274.CapabilityTest' -NotePropertyValue @{'1.0.0'=$true} -Force
$e|ConvertTo-Json -Depth 10|Set-Content "$profile/enabledmods.json"
Add-Content $cfg "`nsolo_notes_mode controlled_validation`nsolo_weapon_notes_fire 1`nbot_telemetry_interval 0.5`n"
$gameDir='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2'
$started=Get-Date
$game=Start-Process "$gameDir/NorthstarLauncher.exe" -WorkingDirectory $gameDir -WindowStyle Normal -PassThru -ArgumentList "-profile=$profile",'-bt7274_capability_test','-novid','-fullscreen','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16 scorelimit 9999 timelimit 30"','+bt7274_capability_test','1','+bt7274_capability_stage','1','+solo_notes_mode','controlled_validation','+solo_weapon_notes_fire','1','+mp_gamemode','tdm','+map','mp_eden'
$shell=(Get-Process -Id $PID).Path
$watch=Start-Process $shell -WindowStyle Hidden -PassThru -ArgumentList '-NoProfile','-File',"$PSScriptRoot/Watch-CapabilityTest.ps1",'-GameProcessId',$game.Id,'-Profile',$profile,'-RunDirectory',$run,'-Started',$started.ToString('o') -RedirectStandardOutput "$run/watcher.stdout.log" -RedirectStandardError "$run/watcher.stderr.log"
[ordered]@{game_pid=$game.Id;watcher_pid=$watch.Id;profile=$profile;run=$run;native_sha256=$previous.dll_sha256;started=$started.ToString('o')}|ConvertTo-Json|Set-Content "$repo/target/v20-capability-session.json"
Get-Content "$repo/target/v20-capability-session.json"
