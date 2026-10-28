param([string]$Profile="$env:USERPROFILE/northstar-crash-audit/local-test-profile")
$ErrorActionPreference='Stop'
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close the game before rollback'}
$receipt="$Profile/bt7274-candidate.json"
$meta=Get-Content $receipt -Raw|ConvertFrom-Json
if(!$meta.eden_repair.backup){throw 'No Eden repair deployment receipt'}
$backup=[string]$meta.eden_repair.backup
if((Get-FileHash "$backup/plugins/bp_ort.dll").Hash-ne'3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89'){throw 'Rollback is not the verified v20 native'}
if((Get-FileHash "$Profile/plugins/bp_ort.dll").Hash-ne$meta.eden_repair.native_sha256){throw 'Current native differs from the Eden repair receipt'}
$saves=@(Get-ChildItem "$Profile/save_data" -Recurse -File|ForEach-Object {@{path=$_.FullName;hash=(Get-FileHash $_.FullName).Hash}})
$cfg="$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
$before=Join-Path (Split-Path $Profile) ('Notes/backups/before-eden-repair-rollback-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $before -ErrorAction Stop|Out-Null
Copy-Item "$Profile/plugins/bp_ort.dll" "$before/bp_ort.dll"
Copy-Item $cfg "$before/server.cfg"
Copy-Item $receipt "$before/bt7274-candidate.json"
# Retain current gameplay settings and saves; remove only this candidate's flags.
$text=[IO.File]::ReadAllText($cfg)
$text=[regex]::Replace($text,'(?m)^\s*bot_(eden_route_repair|route_continuity|link_detour|corner_height_guard)\s+[^\r\n]*\r?\n?','')
try{
    Copy-Item "$backup/plugins/bp_ort.dll" "$Profile/plugins/bp_ort.dll" -Force
    [IO.File]::WriteAllText($cfg,$text)
    $meta.native_sha256='3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89'
    $meta.PSObject.Properties.Remove('eden_repair')
    $meta|ConvertTo-Json -Depth 10|Set-Content $receipt
    foreach($s in $saves){if((Get-FileHash $s.path).Hash-ne$s.hash){throw 'Current save changed during rollback'}}
}catch{
    Copy-Item "$before/bp_ort.dll" "$Profile/plugins/bp_ort.dll" -Force
    Copy-Item "$before/server.cfg" $cfg -Force
    Copy-Item "$before/bt7274-candidate.json" $receipt -Force
    throw
}
[pscustomobject]@{state='restored_v20';current_saves_preserved=$saves.Count;backup=$before}
