param([string]$Profile="$env:USERPROFILE/northstar-crash-audit/local-test-profile",[string]$ValidationDirectory,[switch]$Rollback)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
. "$PSScriptRoot/Northstar-ModState.ps1"
function Get-ContentHash([string]$Path){$h=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($Path);try{[BitConverter]::ToString($h.ComputeHash($f)).Replace('-','')}finally{$f.Dispose();$h.Dispose()}}
if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'local-test-profile'){throw 'Normal solo profile only'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close the game before changing this mod'}
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
$script='mod/scripts/vscripts/bt7274_frag_self_damage.nut'
$name='BT7274.FragSelfDamage'
if(!$Rollback){
 if(!$ValidationDirectory){throw 'A completed isolated validation is required'}
 $s=Get-Content "$ValidationDirectory/status.json" -Raw|ConvertFrom-Json
 if($s.state-ne'passed'-or!$s.cleanup-or!$s.normal_unchanged-or$s.cases-ne52-or$s.matrices.Count-ne4-or!$s.lobby){throw 'Incomplete isolated verification'}
 $e=Get-Content "$ValidationDirectory/evidence.json" -Raw|ConvertFrom-Json
 if($e.script_sha256-ne(Get-ContentHash "$repo/$name/$script")-or$e.manifest_sha256-ne(Get-ContentHash "$repo/$name/mod.json")-or$e.raw_sha256-ne(Get-ContentHash "$ValidationDirectory/raw-session.log")){throw 'Validation source/log hash mismatch'}
 if($e.cases-ne52-or$e.runtime_errors-ne0-or$e.natural_scaled_hits-lt1){throw 'Insufficient damage execution evidence'}
}
$backup=Join-Path (Split-Path $repo) ('Notes/backups/before-frag-self-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $backup -Force|Out-Null
Copy-Item $cfg "$backup/config-before.cfg"
Copy-Item "$Profile/enabledmods.json" "$backup/enabled-before.json"
if(Test-Path "$Profile/mods/$name"){Copy-Item "$Profile/mods/$name" "$backup/$name" -Recurse}
if(Test-Path "$Profile/save_data"){Copy-Item "$Profile/save_data" "$backup/current-save-backup" -Recurse}
$guard=@(Get-ChildItem "$Profile/save_data" -Recurse -File|ForEach-Object{@{path=$_.FullName;hash=(Get-ContentHash $_.FullName)}})
$native=Get-ContentHash "$Profile/plugins/bp_ort.dll"
$core=Get-ContentHash "$Profile/Northstar.dll"
$enabled=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
$config=[IO.File]::ReadAllText($cfg)
$clean=[regex]::Replace($config,'(?m)^\s*bt7274_bot_frag_self_damage(?:_scale|_log)?\s+[^\r\n]*(?:\r?\n|$)','')
try{
 if($Rollback){Disable-NorthstarMod $enabled $name $Profile;$newConfig=$clean}
 else{
  Copy-Item "$repo/$name" "$Profile/mods" -Recurse -Force
  $enabled|Add-Member -NotePropertyName $name -NotePropertyValue @{'1.0.0'=$true} -Force
  $newConfig=$clean.TrimEnd()+"`r`n`r`nbt7274_bot_frag_self_damage 1`r`nbt7274_bot_frag_self_damage_scale 0.25`r`nbt7274_bot_frag_self_damage_log 0`r`n"
 }
 [IO.File]::WriteAllText($cfg,$newConfig)
 $enabled|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
 if((Get-ContentHash "$Profile/plugins/bp_ort.dll")-ne$native-or(Get-ContentHash "$Profile/Northstar.dll")-ne$core){throw 'Native/core changed unexpectedly'}
 foreach($g in $guard){if((Get-ContentHash $g.path)-ne$g.hash){throw 'Current save changed unexpectedly'}}
 $receipt=[ordered]@{state=$(if($Rollback){'disabled'}else{'installed_for_playtest'});installed=(Get-Date).ToString('o');version='1.0.0';scale=$(if($Rollback){1.0}else{0.25});backup=$backup;native_sha256=$native;core_sha256=$core;saves_preserved=$true;validation=$ValidationDirectory;script_sha256=$(if(!$Rollback){Get-ContentHash "$Profile/mods/$name/$script"}else{$null})}
 $receipt|ConvertTo-Json|Set-Content "$Profile/bt7274-frag-self-damage.json"
 $receipt|ConvertTo-Json|Set-Content "$backup/receipt.json"
 $receipt|ConvertTo-Json
}catch{
 Copy-Item "$backup/config-before.cfg" $cfg -Force
 Copy-Item "$backup/enabled-before.json" "$Profile/enabledmods.json" -Force
 # A newly copied mod must not be auto-enabled if the previous manifest lacked it.
 $restore=Get-Content "$Profile/enabledmods.json" -Raw|ConvertFrom-Json
 if(!$restore.PSObject.Properties[$name]){Disable-NorthstarMod $restore $name $Profile;$restore|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"}
 if(Test-Path "$backup/$name"){Copy-Item "$backup/$name/*" "$Profile/mods/$name" -Recurse -Force}
 throw
}
