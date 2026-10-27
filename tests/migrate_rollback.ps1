$ErrorActionPreference='Stop'
function Require([bool]$ok,[string]$message){if(-not $ok){throw $message};"PASS: $message"}
$root=Join-Path ([IO.Path]::GetTempPath()) ('rename-rollback-'+[guid]::NewGuid().ToString('N'))
$profile=Join-Path $root 'profile';$source=Join-Path $root 'source';$backups=Join-Path $root 'backups'
$migrate=Join-Path $PSScriptRoot '../tools/Migrate-BT7274Rename.ps1'
$restore=Join-Path $PSScriptRoot '../tools/Restore-BT7274Rename.ps1'
$names='BT7274.BotLifecycle','BT7274.BotDecisions','BT7274.LocalPersistence','BT7274.TacticalRecharge','BT7274.WeaponHandling','BT7274.WeaponReload'
try{
 New-Item -ItemType Directory -Path "$profile/save_data/Legacy.LocalPersistence","$profile/mods/Solo.WeaponNotes","$profile/mods/Legacy.LocalPersistence","$profile/cfg" -Force|Out-Null
 '{"Legacy.LocalPersistence":true,"Solo.WeaponNotes":true}'|Set-Content "$profile/enabledmods.json"
 'legacy_ads_trial 1'|Set-Content "$profile/cfg/server.cfg"
 'initial-progress'|Set-Content "$profile/save_data/Legacy.LocalPersistence/progress.json"
 'old-notebook'|Set-Content "$profile/mods/Solo.WeaponNotes/version.txt"
 $enabledHash=(Get-FileHash "$profile/enabledmods.json").Hash
 foreach($name in $names){New-Item -ItemType Directory -Path "$source/$name" -Force|Out-Null;'{}'|Set-Content "$source/$name/mod.json"}
 $threw=$false;try{& $migrate -Profile $profile -BackupRoot $backups -InstallFrom $source -Apply|Out-Null}catch{$threw=$true}
 Require $threw 'Missing notebook fails complete install preflight'
 Require (-not(Test-Path $backups)) 'Preflight failure writes no backup or deployment'
 Require ((Get-FileHash "$profile/enabledmods.json").Hash -eq $enabledHash) 'Preflight failure preserves original enablement'
 New-Item -ItemType Directory -Path "$source/Solo.WeaponNotes" -Force|Out-Null
 '{}'|Set-Content "$source/Solo.WeaponNotes/mod.json";'new-notebook'|Set-Content "$source/Solo.WeaponNotes/version.txt"
 # Deliberately force equal timestamps: GUID identity must still prevent reuse.
 function Get-Date { param($Format) '20261027-000000' }
 & $migrate -Profile $profile -BackupRoot $backups -InstallFrom $source -Apply|Out-Null
 $first=@(Get-ChildItem $backups -Directory)[0]
 $firstHash=(Get-FileHash "$($first.FullName)/enabledmods.json").Hash
 & $migrate -Profile $profile -BackupRoot $backups -InstallFrom $source -Apply|Out-Null
 Require (@(Get-ChildItem $backups -Directory).Count -eq 2) 'Equal timestamps create distinct backup directories'
 Require ((Get-FileHash "$($first.FullName)/enabledmods.json").Hash -eq $firstHash -and $firstHash -eq $enabledHash) 'Rerun cannot overwrite original rollback configuration'
 $second=@(Get-ChildItem $backups -Directory|Where-Object{$_.FullName -ne $first.FullName})[0]
 $beforeReject=(Get-FileHash "$profile/enabledmods.json").Hash
 $threw=$false;try{& $restore -Profile $profile -MigrationBackup $second.FullName -Apply|Out-Null}catch{$threw=$true}
 Require ($threw -and (Get-FileHash "$profile/enabledmods.json").Hash -eq $beforeReject) 'Already-migrated rerun backup is refused without disabling either family'
 'current-progress'|Set-Content "$profile/save_data/BT7274.LocalPersistence/progress.json"
 & $restore -Profile $profile -MigrationBackup $first.FullName|Out-Null
 Require ((Get-Content "$profile/mods/Solo.WeaponNotes/version.txt") -eq 'new-notebook') 'Rollback dry run changes no packages'
 & $restore -Profile $profile -MigrationBackup $first.FullName -Apply|Out-Null
 $e=Get-Content -Raw "$profile/enabledmods.json"|ConvertFrom-Json
 Require ($e.'Legacy.LocalPersistence' -eq $true) 'Rollback restores original family'
 Require (@($names|Where-Object{$e.$_ -ne $false}).Count -eq 0) 'Rollback explicitly disables every installed renamed package'
 Require ((Get-Content "$profile/mods/Solo.WeaponNotes/version.txt") -eq 'old-notebook') 'Rollback restores in-place notebook replacement'
 Require ((Get-Content "$profile/cfg/server.cfg") -eq 'legacy_ads_trial 1') 'Rollback restores original configuration'
 Require ((Get-Content "$profile/save_data/Legacy.LocalPersistence/progress.json") -eq 'current-progress') 'Rollback preserves post-migration progress on old key'
 Require ((Get-Content "$profile/save_data/BT7274.LocalPersistence/progress.json") -eq 'current-progress') 'Rollback retains migrated save too'
 Require ((Get-Content "$($first.FullName)/save_data/Legacy.LocalPersistence/progress.json") -eq 'initial-progress') 'Historical backup remains immutable'
 'progress-after-rollback'|Set-Content "$profile/save_data/Legacy.LocalPersistence/progress.json"
 & $restore -Profile $profile -MigrationBackup $first.FullName -Apply|Out-Null
 Require ((Get-Content "$profile/save_data/Legacy.LocalPersistence/progress.json") -eq 'progress-after-rollback') 'Repeated rollback never overwrites subsequent progress'
 # Reconstruct an interrupted install: old enablement plus new packages on disk.
 Remove-Item "$profile/bt7274-rename-rollback.json"
 Copy-Item "$($first.FullName)/enabledmods.json" "$profile/enabledmods.json" -Force
 Remove-Item "$profile/mods/BT7274.BotDecisions" -Recurse
 'old-complete'|Set-Content "$profile/save_data/Legacy.LocalPersistence/second.json"
 # Model a failed copy: inactive new directory is incomplete, old remains complete.
 Remove-Item "$($first.FullName)/completed"
 Remove-Item "$profile/save_data/BT7274.LocalPersistence/progress.json"
 'partial'|Set-Content "$profile/save_data/BT7274.LocalPersistence/partial.json"
 & $restore -Profile $profile -MigrationBackup $first.FullName -Apply|Out-Null
 $e=Get-Content -Raw "$profile/enabledmods.json"|ConvertFrom-Json
 Require ((Get-Content "$profile/save_data/Legacy.LocalPersistence/second.json") -eq 'old-complete' -and (Test-Path "$profile/save_data/Legacy.LocalPersistence/progress.json")) 'Inactive partial save never replaces complete current original'
 Require ($e.'BT7274.LocalPersistence' -eq $false -and $e.'Legacy.LocalPersistence' -eq $true) 'Rollback safely handles partially installed state'
 $wrong=Join-Path $root 'wrong';New-Item -ItemType Directory -Path $wrong|Out-Null
 $threw=$false;try{& $restore -Profile $wrong -MigrationBackup $first.FullName -Apply|Out-Null}catch{$threw=$true}
 Require $threw 'Backup cannot restore a different profile'
}finally{if(Test-Path $root){Remove-Item -LiteralPath $root -Recurse -Force}}
