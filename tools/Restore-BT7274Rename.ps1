<# Roll back a recorded rename migration. Dry-run by default. CURRENT migrated
saves are copied back to old keys, never replaced by historical backup saves.
All current affected files are backed up again before restoration. #>
param([Parameter(Mandatory)][string]$Profile,
      [Parameter(Mandatory)][string]$MigrationBackup,
      [switch]$Apply)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Northstar-ModState.ps1"
$Profile=(Resolve-Path -LiteralPath $Profile).Path
$MigrationBackup=(Resolve-Path -LiteralPath $MigrationBackup).Path
if(Get-Process -Name NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close Northstar/Titanfall 2 before rollback.'}
$m=Get-Content -Raw -LiteralPath (Join-Path $MigrationBackup 'migration.json') | ConvertFrom-Json
if($m.schema -ne 1 -or $m.profile -ne $Profile){throw 'Migration backup does not belong to this profile.'}
if($m.old_prefix -notmatch '^[A-Za-z0-9]+$'){throw 'Invalid prefix in migration manifest.'}
function Within($root,$relative){
    $path=[IO.Path]::GetFullPath((Join-Path $root $relative))
    $prefix=$root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Manifest path escapes its root.'}
    $path
}
$receiptPath=Join-Path $Profile 'bt7274-rename-rollback.json'
if(Test-Path -LiteralPath $receiptPath){
    $receipt=Get-Content -Raw -LiteralPath $receiptPath|ConvertFrom-Json
    if($receipt.backup -eq $MigrationBackup){'This migration was already rolled back; current progress/configuration retained.';return}
}
$enabled=Get-Content -Raw -LiteralPath (Join-Path $MigrationBackup 'enabledmods.json') | ConvertFrom-Json
foreach($prop in @($enabled.PSObject.Properties)){
    if($prop.Name -like 'BT7274.*' -and (Test-NorthstarModEnabled $prop.Value)){
        throw 'This backup already contains migrated enablement. Select the ORIGINAL pre-migration backup, not a rerun snapshot.'
    }
}
$currentEnabled=Get-Content -Raw -LiteralPath (Join-Path $Profile 'enabledmods.json')|ConvertFrom-Json
$committed=Test-Path -LiteralPath (Join-Path $MigrationBackup 'completed') -PathType Leaf
# Explicit false keys are essential: absence can auto-enable an installed mod.
foreach($d in @(Get-ChildItem -LiteralPath (Join-Path $Profile 'mods') -Directory -Filter 'BT7274.*')){
    Disable-NorthstarMod $enabled $d.Name $Profile
}
foreach($p in @($m.packages)){
    if($p.name -notmatch '^(BT7274\.[A-Za-z0-9]+|Solo\.WeaponNotes)$'){throw 'Invalid package in manifest.'}
    if($p.existed -and -not(Test-Path -LiteralPath (Join-Path $MigrationBackup "mods-replaced/$($p.name)") -PathType Container)){throw "Missing package backup: $($p.name)"}
    if(-not $p.existed){Disable-NorthstarMod $enabled $p.name $Profile}
}
foreach($cfg in @($m.cfg)){if(-not(Test-Path -LiteralPath (Within $MigrationBackup "cfg/$cfg") -PathType Leaf)){throw "Missing configuration backup: $cfg"};$null=Within $Profile $cfg}
foreach($name in @($m.saves)){if($name -notmatch ('^'+[regex]::Escape($m.old_prefix)+'\.[A-Za-z0-9]+$')){throw 'Invalid save directory in manifest.'}}
if(-not $Apply){'Dry run only: restore packages/configuration, disable renamed add-ons, retain CURRENT progress.';return}
$rollback=Join-Path (Split-Path $MigrationBackup) ('rollback-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $rollback | Out-Null
Copy-Item -LiteralPath (Join-Path $Profile 'enabledmods.json') -Destination (Join-Path $rollback 'enabledmods.json')
foreach($cfg in @($m.cfg)){
    $dest=Within $Profile $cfg;$snap=Within $rollback "cfg/$cfg"
    New-Item -ItemType Directory -Path (Split-Path $snap) -Force | Out-Null
    if(Test-Path -LiteralPath $dest){Copy-Item -LiteralPath $dest -Destination $snap}
}
foreach($p in @($m.packages)){
    $dest=Join-Path $Profile "mods/$($p.name)"
    if(Test-Path -LiteralPath $dest){New-Item -ItemType Directory -Path (Join-Path $rollback 'mods') -Force|Out-Null;Copy-Item -LiteralPath $dest -Destination (Join-Path $rollback "mods/$($p.name)") -Recurse}
}
# Keep a current copy of both key families before copying active progress back.
foreach($name in @($m.saves)){
    $newName='BT7274'+$name.Substring($m.old_prefix.Length)
    foreach($key in @($name,$newName)){
        $src=Join-Path $Profile "save_data/$key"
        if(Test-Path -LiteralPath $src){New-Item -ItemType Directory -Path (Join-Path $rollback 'save_data') -Force|Out-Null;Copy-Item -LiteralPath $src -Destination (Join-Path $rollback "save_data/$key") -Recurse}
    }
}
foreach($name in @($m.saves)){
    $newName='BT7274'+$name.Substring($m.old_prefix.Length)
    $src=Join-Path $Profile "save_data/$newName";$dest=Join-Path $Profile "save_data/$name"
    $activeNew=$currentEnabled.PSObject.Properties[$newName]
    $activeOld=$currentEnabled.PSObject.Properties[$name]
    if($committed -and $activeNew -and (Test-NorthstarModEnabled $activeNew.Value) -and (-not $activeOld -or -not (Test-NorthstarModEnabled $activeOld.Value)) -and (Test-Path -LiteralPath $src)){
        # Only a completed migration with the renamed family active can own progress.
        # An interrupted/inactive partial copy must never replace old current saves.
        # Copy into a sibling staging directory and verify BEFORE changing old keys.
        $stage=$dest+'.rollback-'+[guid]::NewGuid().ToString('N')
        Copy-Item -LiteralPath $src -Destination $stage -Recurse
        foreach($f in Get-ChildItem -LiteralPath $src -File -Recurse){
            $rel=$f.FullName.Substring($src.Length).TrimStart('\','/')
            if((Get-FileHash -LiteralPath $f.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $stage $rel)).Hash){throw 'Current save verification failed.'}
        }
        Assert-NorthstarProfilePath $Profile $dest
        Assert-NorthstarProfilePath $Profile $stage
        if(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Recurse}
        Move-Item -LiteralPath $stage -Destination $dest
    }
}
foreach($p in @($m.packages)){
    if($p.existed){
        $dest=Join-Path $Profile "mods/$($p.name)"
        Assert-NorthstarProfilePath $Profile $dest
        if(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Recurse}
        Copy-Item -LiteralPath (Join-Path $MigrationBackup "mods-replaced/$($p.name)") -Destination $dest -Recurse
    }
}
foreach($cfg in @($m.cfg)){Copy-Item -LiteralPath (Within $MigrationBackup "cfg/$cfg") -Destination (Within $Profile $cfg) -Force}
# Commit enablement last. Never leave both families enabled after a successful rollback.
$enabled | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $Profile 'enabledmods.json') -Encoding UTF8
@{backup=$MigrationBackup;current_backup=$rollback}|ConvertTo-Json|Set-Content -LiteralPath $receiptPath -Encoding UTF8
"Rollback complete; CURRENT affected files backed up at $rollback. Verify startup and saves before play."
