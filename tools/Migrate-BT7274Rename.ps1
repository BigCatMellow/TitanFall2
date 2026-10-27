<#
Migrates ONE Northstar profile from the previous personal add-on prefix to the
BT7274 prefix used by this repository. Dry run by default; pass -Apply to act.

What it does (with -Apply):
  1. Refuses to run while NorthstarLauncher/Titanfall2 is running.
  2. Discovers the previous prefix from enabledmods.json (the profile is the only
     source of the old name; the repository no longer contains it).
  3. Backs up enabledmods.json, every .cfg that mentions old convars and every
     old save_data folder into <BackupRoot>/bt7274-migration-<timestamp>.
  4. COPIES (never moves) save_data/<old>.<Suffix> to save_data/BT7274.<Suffix>.
     An existing destination with different content stops the run unless -Force.
  5. Optionally installs the renamed packages from -InstallFrom (a checkout of
     this repository) into mods/, after backing up any same-named destination.
  6. enabledmods.json: BT7274.<Suffix> inherits the old value; the old key is set
     to false (explicitly disabled, never deleted: absence can auto-enable, and
     both enabled would define the same script globals twice).
  7. Renames convars at line start in profile .cfg files (<old>_x -> bt7274_x).
CURRENT saves are only copied; nothing is deleted. Old mod folders stay on disk,
disabled. Rollback: close the game, restore the backed-up enabledmods.json and
.cfg files; the original save_data folders were never modified.
#>
param(
    [Parameter(Mandatory)][string]$Profile,
    [string]$BackupRoot,
    [string]$InstallFrom,
    [switch]$Apply,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$NewPrefix = 'BT7274'
$Suffixes = 'LocalPersistence','BotLifecycle','BotDecisions','TacticalRecharge','WeaponHandling',
    'WeaponReload','MapSurvey','BotCycleTest','DecisionTest','WeaponIntegrationTest','TacticalProbe','ReloadTest'
$Packages = 'BotLifecycle','BotDecisions','LocalPersistence','TacticalRecharge','WeaponHandling','WeaponReload'

function Say($text) { Write-Output ($(if ($Apply) { '' } else { '[dry-run] ' }) + $text) }
function Hash-Tree($dir) {
    if (-not (Test-Path -LiteralPath $dir)) { return @{} }
    $map = @{}
    Get-ChildItem -LiteralPath $dir -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring((Resolve-Path -LiteralPath $dir).Path.Length).TrimStart('\', '/')
        $map[$rel] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    $map
}
function Same-Tree($a, $b) {
    $ha = Hash-Tree $a; $hb = Hash-Tree $b
    if ($ha.Count -ne $hb.Count) { return $false }
    foreach ($k in $ha.Keys) { if ($hb[$k] -ne $ha[$k]) { return $false } }
    $true
}

$Profile = (Resolve-Path -LiteralPath $Profile).Path
if (Get-Process -Name NorthstarLauncher, Titanfall2 -ErrorAction SilentlyContinue) { throw 'Close Northstar/Titanfall 2 before migrating.' }
$enabledPath = Join-Path $Profile 'enabledmods.json'
if (-not (Test-Path -LiteralPath $enabledPath)) { throw "No enabledmods.json in $Profile" }
$enabled = Get-Content -Raw -LiteralPath $enabledPath | ConvertFrom-Json

$pattern = '^(?<prefix>[A-Za-z0-9]+)\.(?<suffix>' + ($Suffixes -join '|') + ')$'
$old = @($enabled.PSObject.Properties.Name | Where-Object { $_ -match $pattern -and $Matches.prefix -ne $NewPrefix } |
    ForEach-Object { $null = $_ -match $pattern; $Matches.prefix } | Sort-Object -Unique)
if ($old.Count -eq 0) { Say 'No previous-prefix add-ons found in enabledmods.json; nothing to migrate.'; return }
if ($old.Count -gt 1) { throw "Several candidate prefixes found ($($old -join ', ')); migrate manually." }
$OldPrefix = $old[0]
$oldConvar = $OldPrefix.ToLowerInvariant() + '_'
$newConvar = $NewPrefix.ToLowerInvariant() + '_'
Say "Profile: $Profile"
Say "Previous prefix detected from enabledmods.json; new prefix: $NewPrefix"

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $BackupRoot) { $BackupRoot = Join-Path (Split-Path $Profile) 'migration-backups' }
$backup = Join-Path $BackupRoot "bt7274-migration-$stamp"
$cfgFiles = @(Get-ChildItem -LiteralPath $Profile -Recurse -File -Filter *.cfg |
    Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match ('(?m)^\s*' + [regex]::Escape($oldConvar)) })
$saveRoot = Join-Path $Profile 'save_data'
$oldSaves = @(if (Test-Path -LiteralPath $saveRoot) {
    Get-ChildItem -LiteralPath $saveRoot -Directory | Where-Object { $_.Name -like "$OldPrefix.*" } })

# Pre-flight: refuse conflicting destinations before touching anything.
foreach ($dir in $oldSaves) {
    $dest = Join-Path $saveRoot ($NewPrefix + $dir.Name.Substring($OldPrefix.Length))
    if ((Test-Path -LiteralPath $dest) -and -not (Same-Tree $dir.FullName $dest) -and -not $Force) {
        throw "save_data destination $(Split-Path $dest -Leaf) already exists with different content; inspect it or rerun with -Force (destination is backed up first)."
    }
}
if ($InstallFrom) {
    foreach ($p in $Packages) {
        if (-not (Test-Path -LiteralPath (Join-Path $InstallFrom "$NewPrefix.$p/mod.json"))) { throw "-InstallFrom lacks $NewPrefix.$p" }
    }
}

Say "Backup folder: $backup"
if ($Apply) {
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    Copy-Item -LiteralPath $enabledPath -Destination (Join-Path $backup 'enabledmods.json')
    foreach ($cfg in $cfgFiles) {
        $rel = $cfg.FullName.Substring($Profile.Length).TrimStart('\', '/')
        $target = Join-Path $backup "cfg/$rel"
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $cfg.FullName -Destination $target
    }
    foreach ($dir in $oldSaves) { Copy-Item -LiteralPath $dir.FullName -Destination (Join-Path $backup "save_data/$($dir.Name)") -Recurse }
}

foreach ($dir in $oldSaves) {
    $dest = Join-Path $saveRoot ($NewPrefix + $dir.Name.Substring($OldPrefix.Length))
    if ((Test-Path -LiteralPath $dest) -and (Same-Tree $dir.FullName $dest)) { Say "save_data $(Split-Path $dest -Leaf) already matches; unchanged."; continue }
    Say "Copy save_data $($dir.Name.Substring($OldPrefix.Length)) -> $(Split-Path $dest -Leaf) ($((Hash-Tree $dir.FullName).Count) files)"
    if ($Apply) {
        if (Test-Path -LiteralPath $dest) {
            Copy-Item -LiteralPath $dest -Destination (Join-Path $backup "save_data-replaced/$(Split-Path $dest -Leaf)") -Recurse
            Remove-Item -LiteralPath $dest -Recurse
        }
        Copy-Item -LiteralPath $dir.FullName -Destination $dest -Recurse
        if (-not (Same-Tree $dir.FullName $dest)) { throw "Verification failed for $(Split-Path $dest -Leaf)" }
    }
}

if ($InstallFrom) {
    foreach ($name in @($Packages | ForEach-Object { "$NewPrefix.$_" }) + 'Solo.WeaponNotes') {
        $src = Join-Path $InstallFrom $name; $dest = Join-Path $Profile "mods/$name"
        Say "Install package $name"
        if ($Apply) {
            if (Test-Path -LiteralPath $dest) {
                Copy-Item -LiteralPath $dest -Destination (Join-Path $backup "mods-replaced/$name") -Recurse
                Remove-Item -LiteralPath $dest -Recurse
            }
            Copy-Item -LiteralPath $src -Destination $dest -Recurse
        }
    }
}

$changes = 0
foreach ($prop in @($enabled.PSObject.Properties)) {
    if ($prop.Name -notmatch $pattern -or $Matches.prefix -ne $OldPrefix) { continue }
    $newName = "$NewPrefix.$($Matches.suffix)"
    if (-not (Test-Path -LiteralPath (Join-Path $Profile "mods/$newName/mod.json"))) {
        Say "WARNING: mods/$newName is not installed; its key is added but the add-on will be missing until installed."
    }
    $existing = $enabled.PSObject.Properties[$newName]
    # A previous run already disabled the old key; never let that false value
    # switch off the migrated add-on on a rerun.
    if ($existing -and -not $prop.Value) { continue }
    Say "enabledmods: $newName = $($prop.Value); previous key -> false"
    if ($existing) { $enabled.$newName = $prop.Value }
    else { $enabled | Add-Member -NotePropertyName $newName -NotePropertyValue $prop.Value }
    $prop.Value = $false
    $changes++
}
if ($Apply -and $changes) { $enabled | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $enabledPath -Encoding UTF8 }

foreach ($cfg in $cfgFiles) {
    $text = Get-Content -Raw -LiteralPath $cfg.FullName
    $updated = [regex]::Replace($text, '(?m)^(\s*)' + [regex]::Escape($oldConvar), { param($m) $m.Groups[1].Value + $newConvar })
    $count = ([regex]::Matches($text, '(?m)^\s*' + [regex]::Escape($oldConvar))).Count
    Say "cfg $($cfg.FullName.Substring($Profile.Length).TrimStart('\','/')): $count convar line(s) renamed"
    if ($Apply) { [IO.File]::WriteAllText($cfg.FullName, $updated) }
}

$leftover = @(Get-ChildItem -LiteralPath $Profile -Recurse -File -Include *.cfg, *.json, *.txt, *.cmd -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'enabledmods.json' } |
    Where-Object { $_.FullName -notmatch '[\\/](save_data|logs|mods[\\/][^\\/]+\.(' + ($Suffixes -join '|') + '))[\\/]' } |
    Where-Object { (Get-Content -Raw -LiteralPath $_.FullName -ErrorAction SilentlyContinue) -match ('(?i)\b' + [regex]::Escape($OldPrefix) + '[._]') })
foreach ($f in $leftover) { Say "Review manually (still mentions the previous prefix): $($f.FullName.Substring($Profile.Length).TrimStart('\','/'))" }
Say $(if ($Apply) { 'Migration applied. Start the game once and check the log for BT7274 add-ons, restored loadouts and no script errors.' } else { 'Dry run only. Re-run with -Apply to make these changes.' })
