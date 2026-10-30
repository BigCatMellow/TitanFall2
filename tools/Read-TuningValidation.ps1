function Read-TuningValidation([string]$Directory,[string]$Profile){
 if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Isolated profile only'}
 $p=Get-Content "$Directory/progress.json" -Raw|ConvertFrom-Json;$s=Get-Content "$Directory/session.json" -Raw|ConvertFrom-Json;$c=Get-Content "$Directory/context.json" -Raw|ConvertFrom-Json
 if($p.state-ne'passed'-or!$p.lobby-or$p.core-ne'1.31.14.0'-or($p.completed-join',')-ne'nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'-or$c.experiment-ne'tuning_v29'){throw 'Incomplete tuning lifecycle'}
 $native=(Get-FileHash "$Profile/plugins/bp_ort.dll").Hash;$core=(Get-FileHash "$Profile/Northstar.dll").Hash
 $bridge=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash
 if($native-ne$s.native_sha256-or$core-ne$c.core_sha256-or$bridge-ne$s.bridge_sha256){throw 'Tuning runtime mismatch'}
 $log=[IO.File]::ReadAllText("$Directory/raw-session.log")
 if($log-match'SCRIPT ERROR|COMPILE ERROR|BT_FRAG_AWARE_ERROR|BT_FRAG_DAMAGE_ERROR|BOT_MEASURE_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR|FatalError|Access violation|panicked'){throw 'Error in tuning validation'}
 $phases=@([regex]::Matches($log,'TUNING_PHASE name=(\S+) clearance=(\d) escape=(\d) strict_frag=(\d) height=(\d) eden=(\d)')|ForEach-Object{$_.Groups[1].Value+'='+($_.Groups[2..6].Value -join '')})
 if(($phases-join',')-ne'nav_control=00001,nav_guard=11001,nav_respawn=11001,nav_disabled=00001,nav_new_map=11001'){throw "Tuning flag readback mismatch: $phases"}
 foreach($marker in @('BT_FRAG_AWARE_READY','BT_FRAG_AWARE_SAMPLE','BOT_FRAG_ESCAPE','BOT_CLEARANCE_PROBE','BWEAPON_WINDOW','BFRAG_SPAWN')){if(!$log.Contains($marker)){throw "Unexercised tuning channel $marker"}}
 $repo=Split-Path $PSScriptRoot;$hashes=[ordered]@{dll_sha256=$native;core_sha256=$core;bridge_sha256=$bridge}
 foreach($pair in @(@('measurement','automation/runtime-mods/measurement/BT7274.BotMeasurements','BT7274.BotMeasurements','bt7274_bot_measurements.nut'),@('damage_probe','BT7274.FragDamageProbe','BT7274.FragDamageProbe','bt7274_frag_damage_probe.nut'),@('awareness','automation/runtime-mods/frag-awareness/BT7274.FragAwareness','BT7274.FragAwareness','bt7274_frag_awareness.nut'))){
  $installed=(Get-FileHash "$Profile/mods/$($pair[2])/mod/scripts/vscripts/$($pair[3])").Hash
  if($installed-ne(Get-FileHash "$repo/$($pair[1])/mod/scripts/vscripts/$($pair[3])").Hash){throw 'Tuning source mismatch'}
  $hashes[$pair[0]+'_sha256']=$installed
 };[pscustomobject]$hashes
}
