param([Parameter(Mandatory)][string]$RunDirectory,
    [string]$NormalProfile='C:\Users\james\northstar-crash-audit\local-test-profile',
    [string]$TestProfile='C:\Users\james\northstar-crash-audit\map-cycle-test-profile',
    [string]$InitialBackup,[string]$RepositoryRoot=(Split-Path $PSScriptRoot))
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close games before changing loaded packages'}
$progress=Get-Content -Raw "$RunDirectory/progress.json"|ConvertFrom-Json
$processes=Get-Content -Raw "$RunDirectory/processes.json"|ConvertFrom-Json
$packages=Get-Content -Raw "$RunDirectory/runtime-packages.json"|ConvertFrom-Json
$review=Get-Content -Raw "$repo/Notes/candidates/weapons-v19-20261026/runtime-review.json"|ConvertFrom-Json
if($progress.state-ne'passed'-or-not$progress.weapon_integration-or-not$progress.lobby-or($progress.completed-join',')-ne'4,6'-or$progress.core_version-ne'1.31.14.0'){throw 'Require passed client, weapon matrix and lobby/normal return'}
if(-not$review.checks.human_weapon_matrix_completed-or-not$review.checks.added_weapon_profiles_observed-or@($review.checks.PSObject.Properties|Where-Object {$_.Value-ne$true}).Count){throw 'Runtime evidence review did not pass'}
$dll="$repo/target/x86_64-pc-windows-gnu/distribution/bp_ort.dll"
$dllHash=(Get-FileHash $dll).Hash
if($dllHash-ne$processes.dll_sha256-or$dllHash-ne$packages.dll_sha256){throw 'Native DLL differs from tested build'}
foreach($package in $packages.packages){foreach($f in $package.files){if((Get-FileHash -LiteralPath "$repo/$($package.name)/$($f.path)").Hash-ne$f.sha256){throw "Source differs from tested package: $($package.name)/$($f.path)"}}}
if((Get-Item "$NormalProfile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'Unexpected normal Northstar core'}
if(-not$InitialBackup){$InitialBackup=(Get-Content -Raw "$repo/target/weapon-integration-backup.txt").Trim()}
if(-not(Test-Path "$InitialBackup/map-cycle-test-profile/server.cfg")){throw 'Initial idle test configuration backup missing'}
$backup=Join-Path (Split-Path $repo) ('Notes/backups/before-weapons-v19-deploy-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path "$backup/mods" -Force|Out-Null
$cfg="$NormalProfile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item "$NormalProfile/plugins/bp_ort.dll" "$backup/bp_ort.dll"
Copy-Item $cfg "$backup/server.cfg"
Copy-Item "$NormalProfile/enabledmods.json" "$backup/enabledmods.json"
Copy-Item -LiteralPath "$NormalProfile/save_data" -Destination "$backup/save_data" -Recurse
$saves=@(Get-ChildItem "$NormalProfile/save_data" -Recurse -File|ForEach-Object {@{path=$_.FullName;hash=(Get-FileHash -LiteralPath $_.FullName).Hash}})
function Copy-Package([string]$source,[string]$destination){
    foreach($f in Get-ChildItem -LiteralPath $source -Recurse -File){$target=Join-Path $destination ([IO.Path]::GetRelativePath($source,$f.FullName));New-Item -ItemType Directory -Path (Split-Path $target) -Force|Out-Null;Copy-Item -LiteralPath $f.FullName -Destination $target -Force}
}
$existed=@{}
foreach($p in $packages.packages){$path="$NormalProfile/mods/$($p.name)";$existed[$p.name]=Test-Path $path;if($existed[$p.name]){Copy-Package $path "$backup/mods/$($p.name)"}}
try{
    Copy-Item $dll "$NormalProfile/plugins/bp_ort.dll" -Force
    $enabled=Get-Content -Raw "$NormalProfile/enabledmods.json"|ConvertFrom-Json -AsHashtable
    foreach($p in $packages.packages){Copy-Package "$repo/$($p.name)" "$NormalProfile/mods/$($p.name)";$enabled[$p.name]=@{$p.version=$true}}
    $enabled|ConvertTo-Json -Depth 7|Set-Content "$NormalProfile/enabledmods.json"
    $text=Get-Content -Raw $cfg
    $text=[regex]::Replace($text,'(?m)^(james_ads_trial|solo_weapon_balance|solo_weapon_balance_bots)\s+.*\r?\n?','')
    $text+="`r`n// Runtime-verified v19 human weapon trial; bot balance opt-in stays off.`r`njames_ads_trial 1`r`nsolo_weapon_balance 1`r`nsolo_weapon_balance_bots 0`r`n"
    Set-Content $cfg $text
    foreach($p in $packages.packages){foreach($f in $p.files){if((Get-FileHash -LiteralPath "$NormalProfile/mods/$($p.name)/$($f.path)").Hash-ne$f.sha256){throw 'Installed package hash mismatch'}}}
    foreach($s in $saves){if((Get-FileHash -LiteralPath $s.path).Hash-ne$s.hash){throw 'A current normal save changed during installation'}}
    if((Get-FileHash "$NormalProfile/plugins/bp_ort.dll").Hash-ne$dllHash){throw 'Installed native hash mismatch'}
}catch{
    Copy-Item "$backup/bp_ort.dll" "$NormalProfile/plugins/bp_ort.dll" -Force
    Copy-Item "$backup/server.cfg" $cfg -Force
    Copy-Item "$backup/enabledmods.json" "$NormalProfile/enabledmods.json" -Force
    foreach($p in $packages.packages){if($existed[$p.name]){Copy-Package "$backup/mods/$($p.name)" "$NormalProfile/mods/$($p.name)"}elseif(Test-Path "$NormalProfile/mods/$($p.name)/mod.json"){Move-Item -LiteralPath "$NormalProfile/mods/$($p.name)/mod.json" -Destination "$backup/disabled-$($p.name)-mod.json"}}
    throw
}
# Return the isolated harness to idle, retaining tested gameplay packages only.
$testEnabled=Get-Content -Raw "$TestProfile/enabledmods.json"|ConvertFrom-Json -AsHashtable
foreach($name in @('James.DecisionTest','James.WeaponIntegrationTest','James.MapSurvey','James.BotCycleTest','James.MenuPreviewTest')){if($testEnabled.ContainsKey($name)){foreach($version in @($testEnabled[$name].Keys)){$testEnabled[$name][$version]=$false}}}
$testEnabled|ConvertTo-Json -Depth 7|Set-Content "$TestProfile/enabledmods.json"
Copy-Item "$InitialBackup/map-cycle-test-profile/server.cfg" "$TestProfile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg" -Force
Add-Content "$TestProfile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg" "`r`njames_ads_trial 1`r`nsolo_weapon_balance 1`r`nsolo_weapon_balance_bots 0"
[ordered]@{state='deployed';time=(Get-Date).ToString('o');backup=$backup;normal_profile=$NormalProfile;native_sha256=$dllHash;packages=$packages.packages;normal_saves_unchanged=$saves.Count;isolated_harness_disabled=$true;human_ads_enabled=$true;human_balance_enabled=$true;bot_balance_enabled=$false;runtime_run=$RunDirectory}|ConvertTo-Json -Depth 9|Set-Content "$backup/deployment.json"
[ordered]@{state='deployed';backup=$backup;native_sha256=$dllHash;normal_saves_unchanged=$saves.Count;human_ads_enabled=$true;human_balance_enabled=$true;bot_balance_enabled=$false}|ConvertTo-Json
