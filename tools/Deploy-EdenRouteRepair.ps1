param([Parameter(Mandatory)][string]$ValidationDirectory,[Parameter(Mandatory)][string]$DllPath,
    [string]$NormalProfile="$env:USERPROFILE/northstar-crash-audit/local-test-profile",
    [string]$IsolatedProfile="$env:USERPROFILE/northstar-crash-audit/map-cycle-test-profile",[switch]$CheckOnly)
$ErrorActionPreference='Stop'
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close the game before deployment'}
$progress=Get-Content "$ValidationDirectory/progress.json" -Raw|ConvertFrom-Json
$session=Get-Content "$ValidationDirectory/session.json" -Raw|ConvertFrom-Json
$context=Get-Content "$ValidationDirectory/context.json" -Raw|ConvertFrom-Json
$review=Get-Content "$ValidationDirectory/runtime-review.json" -Raw|ConvertFrom-Json
$expected='nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'
if($progress.state-ne'passed'-or!$progress.lobby-or$progress.core-ne'1.31.14.0'-or($progress.completed-join',')-ne$expected){throw 'Require complete lifecycle validation'}
if($context.experiment-ne'eden_repair_v23'-or!$context.directed_walk-or$context.map-ne'mp_eden'-or$context.next_map-ne'mp_complex3'){throw 'Wrong experiment or map evidence'}
$hash=(Get-FileHash -LiteralPath $DllPath).Hash
if($hash-ne$session.native_sha256-or$hash-ne(Get-FileHash "$IsolatedProfile/plugins/bp_ort.dll").Hash){throw 'Candidate differs from tested native'}
if((Get-FileHash "$ValidationDirectory/raw-session.log").Hash-ne$review.log_sha256){throw 'Review log provenance mismatch'}
if($review.error_markers-ne0-or($review.phases.name-join',')-ne$expected-or@($review.phases|Where-Object {!$_.passed}).Count){throw 'Incomplete or erroneous runtime review'}
if((@($review.phases|ForEach-Object {$_.eden_scope_values-join','})-join';')-ne'0;1;1;0;0'){throw 'Eden-only effective scope was not verified'}
if(($review.phases.enabled-join',')-ne'False,True,True,False,True'){throw 'Missing raw switch readback'}
$control=@($review.directed_walks|Where-Object phase -eq 'nav_control')
if($control.Count-ne1-or$control[0].min_goal_distance-lt5000){throw 'Control did not reproduce the hotspot'}
foreach($phase in @('nav_guard','nav_respawn')){
    $walk=@($review.directed_walks|Where-Object phase -eq $phase)
    if($walk.Count-ne1-or!$walk[0].simulation_21_verified-or$walk[0].dead_samples-ne0-or$walk[0].min_goal_distance-ge4500){throw "No verified live detour progress in $phase"}
}
foreach($p in $review.phases|Where-Object map -eq 'mp_eden'){
    if($p.other_bot_slots_observed-ne15-or$p.other_bots_max_xy_excursion-gt50){throw 'Directed test did not keep other bots stationary'}
}
$core=(Get-FileHash "$NormalProfile/Northstar.dll").Hash
if($core-ne$context.core_sha256-or$core-ne'86007DD1DDAC9103508EECA520E2AB89B16DF92780A5F8A67497CCF29567EDB9'){throw 'Core runtime mismatch'}
$bridge='mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut'
if((Get-FileHash "$NormalProfile/$bridge").Hash-ne$session.bridge_sha256){throw 'Normal bridge differs from tested bridge'}
$oldHash=(Get-FileHash "$NormalProfile/plugins/bp_ort.dll").Hash
if($oldHash-ne'3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89'){throw 'Normal profile changed from validated v20; review before deployment'}
if($CheckOnly){[pscustomobject]@{state='preflight_passed';native_sha256=$hash;scope='pilot routes on Eden only'};return}
$backup=Join-Path (Split-Path $NormalProfile) ('Notes/backups/before-eden-repair-v23-'+(Get-Date -Format yyyyMMdd-HHmmss))
if(Test-Path $backup){throw 'Preserve existing backup'}
New-Item -ItemType Directory -Path "$backup/plugins" -Force|Out-Null
$cfg='mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg'
$receipt='bt7274-candidate.json'
Copy-Item "$NormalProfile/plugins/bp_ort.dll" "$backup/plugins/bp_ort.dll"
Copy-Item "$NormalProfile/$cfg" "$backup/server.cfg"
Copy-Item "$NormalProfile/$receipt" "$backup/$receipt"
Copy-Item "$NormalProfile/enabledmods.json" "$backup/enabledmods.json"
Copy-Item "$NormalProfile/save_data" "$backup/save_data" -Recurse
$saves=@(Get-ChildItem "$NormalProfile/save_data" -Recurse -File|ForEach-Object {@{path=$_.FullName;hash=(Get-FileHash $_.FullName).Hash}})
$modsHash=(Get-FileHash "$NormalProfile/enabledmods.json").Hash
try{
    Copy-Item -LiteralPath $DllPath -Destination "$NormalProfile/plugins/bp_ort.dll" -Force
    $text=[IO.File]::ReadAllText("$NormalProfile/$cfg")
    $text=[regex]::Replace($text,'(?m)^\s*bot_(eden_route_repair|route_continuity|link_detour|corner_height_guard)\s+[^\r\n]*\r?\n?','')
    $text+="`r`n// Validated v23 pilot route repair on Eden only.`r`nbot_eden_route_repair 1`r`nbot_route_continuity 0`r`nbot_link_detour 0`r`nbot_corner_height_guard 0`r`n"
    [IO.File]::WriteAllText("$NormalProfile/$cfg",$text)
    $meta=Get-Content "$NormalProfile/$receipt" -Raw|ConvertFrom-Json
    $meta.state='validated_for_playtest';$meta.native_sha256=$hash
    $meta|Add-Member -NotePropertyName eden_repair -NotePropertyValue @{validation=$ValidationDirectory;backup=$backup;scope='Eden pilot routes only';native_sha256=$hash} -Force
    $meta|ConvertTo-Json -Depth 10|Set-Content "$NormalProfile/$receipt"
    foreach($s in $saves){if((Get-FileHash -LiteralPath $s.path).Hash-ne$s.hash){throw 'Current save changed during deployment'}}
    if((Get-FileHash "$NormalProfile/enabledmods.json").Hash-ne$modsHash){throw 'Mod enablement changed during deployment'}
    if((Get-FileHash "$NormalProfile/plugins/bp_ort.dll").Hash-ne$hash){throw 'Installed native verification failed'}
}catch{
    Copy-Item "$backup/plugins/bp_ort.dll" "$NormalProfile/plugins/bp_ort.dll" -Force
    Copy-Item "$backup/server.cfg" "$NormalProfile/$cfg" -Force
    Copy-Item "$backup/$receipt" "$NormalProfile/$receipt" -Force
    throw
}
[ordered]@{state='validated_for_playtest';native_sha256=$hash;previous_native_sha256=$oldHash;normal_saves_unchanged=$saves.Count;enabledmods_unchanged=$true;scope='Eden pilot routes only';time=(Get-Date).ToString('o');backup=$backup;validation=$ValidationDirectory}|ConvertTo-Json|Set-Content "$backup/deployment.json"
Get-Content "$backup/deployment.json"
