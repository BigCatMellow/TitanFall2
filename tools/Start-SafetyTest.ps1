param([string]$Profile="$env:USERPROFILE/northstar-crash-audit/map-cycle-test-profile",
    [Parameter(Mandatory)][string]$DllPath,
    [ValidatePattern('^mp_[a-z0-9_]+$')][string]$Map='mp_eden',
    [ValidatePattern('^mp_[a-z0-9_]+$')][string]$NextMap='mp_lf_meadow',[switch]$NavigationTrial,[switch]$RouteProbe,[switch]$RouteContinuityTrial,[switch]$RouteWalkTrial,[switch]$QueryOnly,[switch]$RouteDetourTrial,[switch]$EdenRepairTrial,[switch]$Measurements)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Northstar-ModState.ps1"
$repo=Split-Path $PSScriptRoot
$gameDir='C:/Program Files (x86)/Steam/steamapps/common/Titanfall2'
foreach($level in @($Map,$NextMap)){
    if(-not(Get-ChildItem "$gameDir/vpk" -Filter "*_$level.bsp.pak000_dir.vpk" -File -ErrorAction Stop)){
        throw "Map assets not found for $level; use an installed internal map ID"
    }
}
if($RouteContinuityTrial -and !$NavigationTrial){throw 'Route continuity requires NavigationTrial'}
if($RouteWalkTrial -and !$RouteContinuityTrial){throw 'Route walk requires RouteContinuityTrial'}
if($RouteDetourTrial -and !$RouteContinuityTrial){throw 'Link detour requires RouteContinuityTrial'}
if($EdenRepairTrial -and (!$RouteContinuityTrial -or $RouteDetourTrial)){throw 'Eden repair requires RouteContinuityTrial without RouteDetourTrial'}
if($QueryOnly -and (!$RouteProbe -or $RouteWalkTrial -or $RouteContinuityTrial)){throw 'QueryOnly requires RouteProbe without movement trials'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is already running'}
if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Safety harness requires the working isolated profile'}
if((Get-Item "$Profile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'Need matching core'}
$run=Join-Path (Split-Path $repo) ('Notes/candidates/v21-tests/safety-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item $cfg "$run/idle.cfg"
Copy-Item "$Profile/enabledmods.json" "$run/enabledmods-before.json"
Copy-Item $DllPath "$Profile/plugins/bp_ort.dll" -Force
$bridgeSource=if($NavigationTrial){"$repo/../local-test-profile/mods/BT7274.BotDecisions"}else{"$repo/BT7274.BotDecisions"}
Copy-Item "$bridgeSource/*" "$Profile/mods/BT7274.BotDecisions" -Recurse -Force
Copy-Item "$repo/automation/runtime-mods/safety/BT7274.SafetyTest" "$Profile/mods" -Recurse -Force
if($RouteProbe){Copy-Item "$repo/automation/runtime-mods/route-probe/BT7274.RouteProbe" "$Profile/mods" -Recurse -Force}
if($Measurements){Copy-Item "$repo/automation/runtime-mods/measurement/BT7274.BotMeasurements" "$Profile/mods" -Recurse -Force}
$serverScript="$Profile/mods/BT7274.SafetyTest/mod/scripts/vscripts/bt7274_safety_test.nut"
$uiScript="$Profile/mods/BT7274.SafetyTest/mod/scripts/vscripts/bt7274_safety_test_ui.nut"
[IO.File]::WriteAllText($serverScript,[IO.File]::ReadAllText($serverScript).Replace('"mp_lf_meadow"','"'+$NextMap+'"'))
if($RouteContinuityTrial){
    $trialConvar=if($EdenRepairTrial){'bot_eden_route_repair'}elseif($RouteDetourTrial){'bot_link_detour'}else{'bot_route_continuity'}
    [IO.File]::WriteAllText($serverScript,[IO.File]::ReadAllText($serverScript).Replace('bot_corner_height_guard',$trialConvar))
}
if($RouteWalkTrial){
    $walk=[IO.File]::ReadAllText("$repo/automation/runtime-mods/route-probe/route_walk_injection.nut")
    if($RouteDetourTrial){$walk=$walk.Replace('GetConVarBool("bot_route_continuity")','GetConVarBool("bot_link_detour")')}
    if($EdenRepairTrial){$walk=$walk.Replace('GetConVarBool("bot_route_continuity")','GetConVarBool("bot_eden_route_repair")')}
    $script=[IO.File]::ReadAllText($serverScript).Replace('print("SAFETY_TEST_PHASE map=', 'BT7274RouteWalk_Setup(name);print("SAFETY_TEST_PHASE map=').Replace('while(Time()<until){wait 5.0;', 'while(Time()<until){wait 5.0;BT7274RouteWalk_Sample(name);')
    [IO.File]::WriteAllText($serverScript,$script+"`n"+$walk)
}
if($QueryOnly){[IO.File]::WriteAllText($serverScript,[IO.File]::ReadAllText($serverScript).Replace('thread BT7274SafetyTest_Run()','// Query-only: no safety/movement phases'))}
[IO.File]::WriteAllText($uiScript,[IO.File]::ReadAllText($uiScript).Replace('mp_eden',$Map))
$enabled=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
foreach($name in @('BT7274.DecisionTest','BT7274.WeaponIntegrationTest','BT7274.CapabilityTest','BT7274.MapSurvey')){Disable-NorthstarMod $enabled $name $Profile}
$enabled|Add-Member -NotePropertyName 'BT7274.SafetyTest' -NotePropertyValue @{'1.0.0'=$true} -Force
if($RouteProbe){$enabled|Add-Member -NotePropertyName 'BT7274.RouteProbe' -NotePropertyValue @{'1.0.0'=$true} -Force}
if($Measurements){$enabled|Add-Member -NotePropertyName 'BT7274.BotMeasurements' -NotePropertyValue @{'1.0.0'=$true} -Force}
$bridgeVersion=(Get-Content "$Profile/mods/BT7274.BotDecisions/mod.json" -Raw|ConvertFrom-Json).Version
Disable-NorthstarMod $enabled 'BT7274.BotDecisions' $Profile
$enabled.'BT7274.BotDecisions'|Add-Member -NotePropertyName $bridgeVersion -NotePropertyValue $true -Force
$enabled|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
Add-Content $cfg "`nsolo_notes_mode controlled_validation`nbot_telemetry_interval 0.5`n"
Add-Content $cfg 'setplaylistvaroverrides "max_players 17 scorelimit 9999 timelimit 30"'
Add-Content $cfg ('bt7274_safety_navigation '+[int][bool]$NavigationTrial)
if($RouteDetourTrial){Add-Content $cfg 'bot_route_continuity 1'}
if($EdenRepairTrial){Add-Content $cfg "bot_route_continuity 0`nbot_link_detour 0"}
if($Measurements){Add-Content $cfg 'bt7274_bot_measurements 1'}
$started=Get-Date
$game=Start-Process "$gameDir/NorthstarLauncher.exe" -WorkingDirectory $gameDir -WindowStyle Hidden -PassThru -ArgumentList "-profile=$Profile",'-bt7274_safety_test','-novid','-windowed','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 17 scorelimit 9999 timelimit 30"','+bt7274_safety_test','1','+bt7274_safety_stage','1','+solo_notes_mode','controlled_validation','+mp_gamemode','tdm','+map',$Map
[ordered]@{experiment=$(if($EdenRepairTrial){'eden_repair_v23'}elseif($RouteDetourTrial){'route_detour_v23'}elseif($QueryOnly){'route_queries_v23'}elseif($RouteWalkTrial){'route_walk_v23'}elseif($RouteContinuityTrial){'route_continuity_v23'}elseif($RouteProbe){'route_research_v23'}elseif($NavigationTrial){'navigation_v22'}else{'safety_v21'});directed_walk=[bool]$RouteWalkTrial;map=$Map;next_map=$NextMap;population=$(if($QueryOnly){'query_only_no_movement_assertions'}elseif($RouteWalkTrial){'one_directed_bot_other_bots_stationary_on_eden'}else{'16bots_inactive_human'});core_sha256=(Get-FileHash "$Profile/Northstar.dll").Hash;harness_sha256=(Get-FileHash $serverScript).Hash;ui_sha256=(Get-FileHash $uiScript).Hash}|ConvertTo-Json|Set-Content "$run/context.json"
$shell=(Get-Process -Id $PID).Path
$watchArgs=@('-NoProfile','-File',"$PSScriptRoot/Watch-SafetyTest.ps1",'-GameProcessId',$game.Id,'-Profile',$Profile,'-RunDirectory',$run,'-Started',$started.ToString('o'))
if($NavigationTrial){$watchArgs+='-NavigationTrial'}
if($RouteProbe){$watchArgs+='-RouteProbe'}
if($QueryOnly){$watchArgs+='-QueryOnly'}
$watch=Start-Process $shell -WindowStyle Hidden -PassThru -ArgumentList $watchArgs -RedirectStandardOutput "$run/watcher.stdout.log" -RedirectStandardError "$run/watcher.stderr.log"
[ordered]@{game_pid=$game.Id;watcher_pid=$watch.Id;profile=$Profile;run=$run;native_sha256=(Get-FileHash $DllPath).Hash;bridge_sha256=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash;started=$started.ToString('o')}|ConvertTo-Json|Set-Content "$repo/target/v21-safety-session.json"
Get-Content "$repo/target/v21-safety-session.json"
Copy-Item "$repo/target/v21-safety-session.json" "$run/session.json"
