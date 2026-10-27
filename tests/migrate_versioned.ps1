$ErrorActionPreference='Stop'
function Require([bool]$ok,[string]$message){if(-not$ok){throw $message};"PASS: $message"}
$root=Join-Path ([IO.Path]::GetTempPath()) ('bt7274-versioned-'+[guid]::NewGuid().ToString('N'))
try{
    $profile=Join-Path $root 'profile'
    New-Item -ItemType Directory "$profile/save_data/Legacy.LocalPersistence","$profile/mods/Legacy.LocalPersistence","$profile/mods/BT7274.LocalPersistence" -Force|Out-Null
    '{"Version":1,"Legacy.LocalPersistence":{"1.1.0":false,"1.2.1":true}}'|Set-Content "$profile/enabledmods.json"
    foreach($name in @('Legacy.LocalPersistence','BT7274.LocalPersistence')){'{"Name":"'+$name+'","Version":"1.2.1"}'|Set-Content "$profile/mods/$name/mod.json"}
    'before'|Set-Content "$profile/save_data/Legacy.LocalPersistence/progress.json"
    & "$PSScriptRoot/../tools/Migrate-BT7274Rename.ps1" -Profile $profile -BackupRoot "$root/backups" -Apply|Out-Null
    $first=Get-ChildItem "$root/backups" -Directory|Select-Object -First 1
    $e=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
    Require ($e.'Legacy.LocalPersistence'.'1.2.1'-eq$false-and$e.'Legacy.LocalPersistence'.'1.1.0'-eq$false) 'Legacy versions are explicitly disabled using Northstar Version1 objects'
    Require ($e.'BT7274.LocalPersistence'.'1.2.1'-eq$true-and$e.'BT7274.LocalPersistence'.'1.1.0'-eq$false) 'New version state is independent and retains selected versions'
    & "$PSScriptRoot/../tools/Migrate-BT7274Rename.ps1" -Profile $profile -BackupRoot "$root/backups" -Apply|Out-Null
    $e=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
    Require ($e.'BT7274.LocalPersistence'.'1.2.1'-eq$true) 'Versioned rerun retains active renamed persistence'
    'current-progress'|Set-Content "$profile/save_data/BT7274.LocalPersistence/progress.json"
    & "$PSScriptRoot/../tools/Restore-BT7274Rename.ps1" -Profile $profile -MigrationBackup $first.FullName -Apply|Out-Null
    $e=Get-Content "$profile/enabledmods.json" -Raw|ConvertFrom-Json
    Require ($e.'BT7274.LocalPersistence'.'1.2.1'-eq$false-and$e.'Legacy.LocalPersistence'.'1.2.1'-eq$true) 'Versioned rollback disables renamed family and restores original enablement'
    Require ((Get-Content "$profile/save_data/Legacy.LocalPersistence/progress.json")-eq'current-progress') 'Versioned rollback carries CURRENT progress back'
}finally{
    $resolved=[IO.Path]::GetFullPath($root)
    if((Split-Path $resolved -Parent)-eq([IO.Path]::GetTempPath().TrimEnd('\','/'))-and(Split-Path $resolved -Leaf)-like'bt7274-versioned-*'){
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
