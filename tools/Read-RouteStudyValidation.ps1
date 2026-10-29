function Read-RouteStudyValidation([string]$Directory,[string]$Profile) {
    if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Use the working isolated profile'}
    $p=Get-Content "$Directory/progress.json" -Raw|ConvertFrom-Json
    $s=Get-Content "$Directory/session.json" -Raw|ConvertFrom-Json
    $c=Get-Content "$Directory/context.json" -Raw|ConvertFrom-Json
    if($p.state-ne'passed'-or!$p.lobby-or$p.core-ne'1.31.14.0'-or($p.completed-join',')-ne'nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'){throw 'Incomplete routing lifecycle validation'}
    if($c.experiment-ne'route_detour_v23'-or$c.directed_walk-or$c.map-ne'mp_relic02'-or$c.next_map-ne'mp_wargames'){throw 'Wrong study validation cohort'}
    $native=(Get-FileHash "$Profile/plugins/bp_ort.dll").Hash
    $core=(Get-FileHash "$Profile/Northstar.dll").Hash
    $bridge=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash
    if($native-ne'BC2C1019D27F537F075611ED6B68A75591D1F2F9924BA8700D82A757BB1000F7'-or$native-ne$s.native_sha256-or$bridge-ne$s.bridge_sha256-or$core-ne$c.core_sha256){throw 'Frozen study runtime mismatch'}
    $log=[IO.File]::ReadAllText("$Directory/raw-session.log")
    foreach($marker in @('BOT_MEASURE_READY','BWEAPON_WINDOW','BFRAG_SPAWN','BFRAG_KILL')){if(!$log.Contains($marker)){throw "Missing measurement validation: $marker"}}
    if($log-match'BOT_MEASURE_ERROR|SCRIPT ERROR|COMPILE ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR|FatalError|Access violation|panicked'){throw 'Measurement/runtime error in validation'}
    $states=@([regex]::Matches($log,'SAFETY_TEST_NAV_STATE phase=(\S+) corner=(true|false)')|ForEach-Object {$_.Groups[1].Value+'='+$_.Groups[2].Value})
    if(($states-join',')-ne'nav_control=false,nav_guard=true,nav_respawn=true,nav_disabled=false,nav_new_map=true'){throw 'Missing detour switch readback'}
    $relative='automation/runtime-mods/measurement/BT7274.BotMeasurements/mod/scripts/vscripts/bt7274_bot_measurements.nut'
    $source=Join-Path (Split-Path $PSScriptRoot) $relative
    $measure=(Get-FileHash "$Profile/mods/BT7274.BotMeasurements/mod/scripts/vscripts/bt7274_bot_measurements.nut").Hash
    if($measure-ne(Get-FileHash $source).Hash){throw 'Measurement source differs from validated installation'}
    [pscustomobject]@{dll_sha256=$native;core_sha256=$core;bridge_sha256=$bridge;measurement_sha256=$measure}
}
