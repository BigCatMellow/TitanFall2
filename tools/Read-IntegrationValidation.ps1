function Read-IntegrationValidation([string]$Directory,[string]$Profile){
    if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Use isolated profile'}
    $p=Get-Content "$Directory/progress.json" -Raw|ConvertFrom-Json
    $s=Get-Content "$Directory/session.json" -Raw|ConvertFrom-Json
    $c=Get-Content "$Directory/context.json" -Raw|ConvertFrom-Json
    if($p.state-ne'passed'-or!$p.lobby-or$p.core-ne'1.31.14.0'-or($p.completed-join',')-ne'nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'-or$c.experiment-ne'integration_v28'){throw 'Incomplete v28 lifecycle validation'}
    $native=(Get-FileHash "$Profile/plugins/bp_ort.dll").Hash
    $core=(Get-FileHash "$Profile/Northstar.dll").Hash
    $bridge=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash
    if($native-ne$s.native_sha256-or$bridge-ne$s.bridge_sha256-or$core-ne$c.core_sha256){throw 'Frozen integration runtime mismatch'}
    $log=[IO.File]::ReadAllText("$Directory/raw-session.log")
    if($log-match'SCRIPT ERROR|COMPILE ERROR|BT_FRAG_DAMAGE_ERROR|BT_FRAG_PROBE_ERROR|BOT_MEASURE_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR|FatalError|Access violation|panicked'){throw 'Runtime error in validation'}
    $observed=@([regex]::Matches($log,'INTEGRATION_PHASE name=(\S+) nearest=(\d) stall=(\d) frag=(\d) clearance=(\d) height=(\d) eden=(\d)')|ForEach-Object{$_.Groups[1].Value+'='+($_.Groups[2..7].Value -join '')})
    if(($observed-join',')-ne'nav_control=000001,nav_guard=111111,nav_respawn=111111,nav_disabled=000001,nav_new_map=111111'){throw "Incomplete new-flag readbacks: $observed"}
    foreach($marker in @('BOT_MEASURE_READY','BWEAPON_WINDOW','BFRAG_SPAWN','BT_FRAG_DAMAGE','BOT_FRAG_INPUT')){if(!$log.Contains($marker)){throw "Unexercised diagnostic channel $marker"}}
    $repo=Split-Path $PSScriptRoot
    $measureRel='mods/BT7274.BotMeasurements/mod/scripts/vscripts/bt7274_bot_measurements.nut'
    $damageRel='mods/BT7274.FragDamageProbe/mod/scripts/vscripts/bt7274_frag_damage_probe.nut'
    $measure=(Get-FileHash "$Profile/$measureRel").Hash;$damage=(Get-FileHash "$Profile/$damageRel").Hash
    if($measure-ne(Get-FileHash "$repo/automation/runtime-mods/measurement/BT7274.BotMeasurements/mod/scripts/vscripts/bt7274_bot_measurements.nut").Hash-or$damage-ne(Get-FileHash "$repo/BT7274.FragDamageProbe/mod/scripts/vscripts/bt7274_frag_damage_probe.nut").Hash){throw 'Diagnostic source differs'}
    [pscustomobject]@{dll_sha256=$native;core_sha256=$core;bridge_sha256=$bridge;measurement_sha256=$measure;damage_probe_sha256=$damage}
}
