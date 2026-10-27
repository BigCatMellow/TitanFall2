$ErrorActionPreference = 'Stop'
# Fixture uses a synthetic previous prefix ("Legacy"); the migration discovers
# the prefix from enabledmods.json, so no real name is needed here.
function Require([bool]$ok, [string]$message) { if (-not $ok) { throw $message }; "PASS: $message" }
$script = Join-Path $PSScriptRoot '../tools/Migrate-BT7274Rename.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('bt7274-migrate-test-' + [guid]::NewGuid().ToString('N'))
try {
    $profile = Join-Path $root 'profile'
    New-Item -ItemType Directory -Path "$profile/save_data/Legacy.LocalPersistence", "$profile/mods/Northstar.CustomServers/mod/cfg", "$profile/mods/BT7274.LocalPersistence" -Force | Out-Null
    '{}' | Set-Content "$profile/mods/BT7274.LocalPersistence/mod.json"
    '{"loadout":1}' | Set-Content "$profile/save_data/Legacy.LocalPersistence/loadouts_1.json"
    '{"Northstar.Client":true,"Legacy.LocalPersistence":true,"Legacy.WeaponReload":false,"Solo.WeaponNotes":true}' | Set-Content "$profile/enabledmods.json"
    "bot_aim_error_scale 0.78`nlegacy_ads_trial 1`n  legacy_weapon_reload 1`n// legacy_note stays`n" | Set-Content "$profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
    $before = Get-FileHash "$profile/save_data/Legacy.LocalPersistence/loadouts_1.json"

    $dry = & $script -Profile $profile -BackupRoot "$root/backups"
    Require (-not (Test-Path "$profile/save_data/BT7274.LocalPersistence")) 'Dry run copies nothing'
    Require (($dry -join "`n") -match 'Dry run only') 'Dry run says so'
    Require (-not (Test-Path "$root/backups")) 'Dry run writes no backup'

    & $script -Profile $profile -BackupRoot "$root/backups" -Apply | Out-Null
    $enabled = Get-Content -Raw "$profile/enabledmods.json" | ConvertFrom-Json
    Require ($enabled.'BT7274.LocalPersistence' -eq $true -and $enabled.'Legacy.LocalPersistence' -eq $false) 'Enabled state moves to the new key; old key explicitly disabled'
    Require ($enabled.'BT7274.WeaponReload' -eq $false -and $enabled.'Legacy.WeaponReload' -eq $false) 'Disabled add-ons stay disabled'
    Require ($enabled.'Northstar.Client' -eq $true -and $enabled.'Solo.WeaponNotes' -eq $true) 'Unrelated mods untouched'
    Require ((Get-FileHash "$profile/save_data/BT7274.LocalPersistence/loadouts_1.json").Hash -eq $before.Hash) 'Save data copied byte-identical'
    Require ((Get-FileHash "$profile/save_data/Legacy.LocalPersistence/loadouts_1.json").Hash -eq $before.Hash) 'Original save data untouched'
    $cfg = Get-Content -Raw "$profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
    Require ($cfg -match '(?m)^bt7274_ads_trial 1' -and $cfg -match '(?m)^  bt7274_weapon_reload 1') 'Convar lines renamed with indentation kept'
    Require ($cfg -match '(?m)^// legacy_note stays' -and $cfg -match 'bot_aim_error_scale 0.78') 'Comments and other settings untouched'
    $backup = Get-ChildItem "$root/backups" -Directory | Select-Object -First 1
    Require ((Test-Path "$($backup.FullName)/enabledmods.json") -and (Test-Path "$($backup.FullName)/save_data/Legacy.LocalPersistence/loadouts_1.json")) 'Backup holds pre-migration files'

    & $script -Profile $profile -BackupRoot "$root/backups" -Apply | Out-Null
    $enabled = Get-Content -Raw "$profile/enabledmods.json" | ConvertFrom-Json
    Require ((Get-FileHash "$profile/save_data/BT7274.LocalPersistence/loadouts_1.json").Hash -eq $before.Hash -and $enabled.'BT7274.LocalPersistence' -eq $true) 'Second run is idempotent and keeps the migrated add-on enabled'

    '{"loadout":2}' | Set-Content "$profile/save_data/BT7274.LocalPersistence/loadouts_1.json"
    $enabled2 = '{"Legacy.LocalPersistence":true}'; $enabled2 | Set-Content "$profile/enabledmods.json"
    $threw = $false
    try { & $script -Profile $profile -BackupRoot "$root/backups" -Apply | Out-Null } catch { $threw = $true }
    Require $threw 'A different existing destination save stops the run'
    Require ((Get-Content -Raw "$profile/save_data/BT7274.LocalPersistence/loadouts_1.json") -match '"loadout":2') 'Newer destination save not overwritten without -Force'

    '{"Legacy.LocalPersistence":true,"Other.LocalPersistence":true}' | Set-Content "$profile/enabledmods.json"
    $threw = $false
    try { & $script -Profile $profile -BackupRoot "$root/backups" | Out-Null } catch { $threw = $true }
    Require $threw 'Ambiguous previous prefixes refuse to guess'
} finally {
    if ((Split-Path $root -Parent) -eq ([IO.Path]::GetTempPath().TrimEnd('\', '/')) -and (Split-Path $root -Leaf) -like 'bt7274-migrate-test-*') {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}
