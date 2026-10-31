function Read-AwarenessValidation([string]$Directory,[string]$Profile){
 $p=Get-Content "$Directory/progress.json" -Raw|ConvertFrom-Json;$s=Get-Content "$Directory/session.json" -Raw|ConvertFrom-Json;$c=Get-Content "$Directory/context.json" -Raw|ConvertFrom-Json
 if($p.state-ne'passed'-or!$p.lobby-or$p.core-ne'1.31.14.0'-or($p.completed-join',')-ne'nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'-or$c.experiment-ne'awareness_v31'){throw 'Incomplete awareness lifecycle'}
 $raw=[IO.File]::ReadAllText("$Directory/raw-session.log")
 if($raw-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_MEASURE_ERROR|BT_FRAG_DAMAGE_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR'){throw 'Runtime errors in awareness validation'}
 $phases=@([regex]::Matches($raw,'AWARE_PHASE name=(\S+) fair=(\d) memory=([\d.]+) self_scale=([\d.]+)')|ForEach-Object{if([double]$_.Groups[3].Value-ne4-or[double]$_.Groups[4].Value-ne0.25){throw 'Wrong awareness/self policy'};$_.Groups[1].Value+'='+$_.Groups[2].Value})
 if(($phases-join',')-ne'nav_control=0,nav_guard=1,nav_respawn=1,nav_disabled=0,nav_new_map=1'){throw 'Awareness lifecycle flag mismatch'}
 foreach($mode in @('visible','memory','patrol')){if($raw-notmatch("BOT_AWARENESS .*mode="+$mode+' ')){throw "Unexercised awareness mode $mode"}}
 $native=(Get-FileHash "$Profile/plugins/bp_ort.dll").Hash;if($native-ne$s.native_sha256){throw 'Native differs from lifecycle'}
 $repo=Split-Path $PSScriptRoot;$hashes=[ordered]@{native_sha256=$native;core_sha256=(Get-FileHash "$Profile/Northstar.dll").Hash;raw_sha256=(Get-FileHash "$Directory/raw-session.log").Hash}
 foreach($pair in @(@('bridge','BT7274.BotDecisions','bt7274_bot_decisions.nut'),@('self_damage','BT7274.FragSelfDamage','bt7274_frag_self_damage.nut'),@('measurement','BT7274.BotMeasurements','bt7274_bot_measurements.nut'),@('damage_probe','BT7274.FragDamageProbe','bt7274_frag_damage_probe.nut'))){$hashes[$pair[0]+'_sha256']=(Get-FileHash "$Profile/mods/$($pair[1])/mod/scripts/vscripts/$($pair[2])").Hash}
 if($hashes.bridge_sha256-ne$s.bridge_sha256-or$hashes.core_sha256-ne$c.core_sha256-or$hashes.self_damage_sha256-ne(Get-FileHash "$repo/BT7274.FragSelfDamage/mod/scripts/vscripts/bt7274_frag_self_damage.nut").Hash){throw 'Runtime component mismatch'}
 [pscustomobject]$hashes
}
