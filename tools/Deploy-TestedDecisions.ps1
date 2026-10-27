param([Parameter(Mandatory)][string]$ValidationDirectory,[Parameter(Mandatory)][string]$ReadinessRetestDirectory,
    [string]$NormalProfile="$env:USERPROFILE\northstar-crash-audit\local-test-profile",
    [string]$RepositoryRoot=(Split-Path $PSScriptRoot),[string]$BackupDirectory)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close the game before changing loaded DLLs'}
$full=Get-Content -Raw "$ValidationDirectory/progress.json"|ConvertFrom-Json
$fullBuild=Get-Content -Raw "$ValidationDirectory/processes.json"|ConvertFrom-Json
$quick=Get-Content -Raw "$ReadinessRetestDirectory/progress.json"|ConvertFrom-Json
$quickBuild=Get-Content -Raw "$ReadinessRetestDirectory/processes.json"|ConvertFrom-Json
if($full.state-ne'passed'-or$full.dedicated-or($full.completed-join',')-ne'0,1,2,3,4,6'){throw 'Full client integration validation is required'}
if($quick.state-ne'passed'-or-not$quick.quick-or($quick.completed-join',')-ne'4,6'){throw 'Final readiness matrix/lobby/normal retest is required'}
$dll="$repo/target/x86_64-pc-windows-gnu/distribution/bp_ort.dll"
$bridge="$repo/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut"
$dllHash=(Get-FileHash -LiteralPath $dll).Hash;$bridgeHash=(Get-FileHash -LiteralPath $bridge).Hash
if($dllHash-ne$fullBuild.dll_sha256-or$dllHash-ne$quickBuild.dll_sha256-or$bridgeHash-ne$quickBuild.bridge_sha256){throw 'Deploy only the exact tested DLL and final bridge'}
if((Get-Item "$NormalProfile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'Unexpected normal profile core runtime'}
if(-not$BackupDirectory){$BackupDirectory=Join-Path (Split-Path $repo) ('Notes/backups/before-v18-normal-deploy-'+(Get-Date -Format yyyyMMdd-HHmmss))}
if(Test-Path $BackupDirectory){throw 'Preserve existing deployment backup'}
New-Item -ItemType Directory -Path "$BackupDirectory/plugins" -Force|Out-Null
$cfg="$NormalProfile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
Copy-Item "$NormalProfile/plugins/bp_ort.dll" "$BackupDirectory/plugins/bp_ort.dll"
Copy-Item $cfg "$BackupDirectory/server.cfg"
Copy-Item "$NormalProfile/enabledmods.json" "$BackupDirectory/enabledmods.json"
Copy-Item -LiteralPath "$NormalProfile/save_data" -Destination $BackupDirectory -Recurse
$existed=Test-Path "$NormalProfile/mods/BT7274.BotDecisions"
if($existed){Copy-Item -LiteralPath "$NormalProfile/mods/BT7274.BotDecisions" -Destination "$BackupDirectory/BT7274.BotDecisions" -Recurse}
$saveHashes=@(Get-ChildItem "$NormalProfile/save_data" -Recurse -File|ForEach-Object{[pscustomobject]@{path=$_.FullName;hash=(Get-FileHash -LiteralPath $_.FullName).Hash}})
$oldDllHash=(Get-FileHash "$NormalProfile/plugins/bp_ort.dll").Hash
try{
    Copy-Item -LiteralPath $dll -Destination "$NormalProfile/plugins/bp_ort.dll" -Force
    if(-not$existed){Copy-Item -LiteralPath "$repo/BT7274.BotDecisions" -Destination "$NormalProfile/mods" -Recurse}
    else{Copy-Item "$repo/BT7274.BotDecisions/mod.json" "$NormalProfile/mods/BT7274.BotDecisions/mod.json" -Force;Copy-Item $bridge "$NormalProfile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut" -Force}
    $mods=Get-Content -Raw "$NormalProfile/enabledmods.json"|ConvertFrom-Json -AsHashtable
    $mods['BT7274.BotDecisions']=@{'1.0.0'=$true};$mods|ConvertTo-Json -Depth 6|Set-Content "$NormalProfile/enabledmods.json"
    $text=Get-Content -Raw $cfg
    $text=[regex]::Replace($text,'(?m)^bot_(navigation_context|target_eligibility|action_policy|step_retry) .*\r?\n?','')
    $text+="`r`n// Tested decisions-v18; original difficulty and human modifiers preserved.`r`nbot_navigation_context 1`r`nbot_target_eligibility 1`r`nbot_action_policy 1`r`nbot_step_retry 1`r`n"
    Set-Content -LiteralPath $cfg -Value $text
    foreach($s in $saveHashes){if((Get-FileHash -LiteralPath $s.path).Hash-ne$s.hash){throw 'A current save changed during deployment'}}
    if((Get-FileHash "$NormalProfile/plugins/bp_ort.dll").Hash-ne$dllHash-or(Get-FileHash "$NormalProfile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash-ne$bridgeHash){throw 'Installed hash verification failed'}
    $status='deployed'
}catch{
    Copy-Item "$BackupDirectory/plugins/bp_ort.dll" "$NormalProfile/plugins/bp_ort.dll" -Force
    Copy-Item "$BackupDirectory/server.cfg" $cfg -Force
    Copy-Item "$BackupDirectory/enabledmods.json" "$NormalProfile/enabledmods.json" -Force
    if($existed){Copy-Item "$BackupDirectory/BT7274.BotDecisions/*" "$NormalProfile/mods/BT7274.BotDecisions" -Recurse -Force}
    elseif(Test-Path "$NormalProfile/mods/BT7274.BotDecisions/mod.json"){Move-Item -LiteralPath "$NormalProfile/mods/BT7274.BotDecisions/mod.json" -Destination "$BackupDirectory/disabled-new-bridge-mod.json"}
    throw
}
[ordered]@{state=$status;profile=$NormalProfile;backup=$BackupDirectory;before_dll=$oldDllHash;installed_dll=$dllHash;bridge=$bridgeHash;saves_unchanged=$saveHashes.Count;bridge_preexisted=$existed;full_validation=$ValidationDirectory;readiness_retest=$ReadinessRetestDirectory;time=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content "$BackupDirectory/deployment.json"
Get-Content "$BackupDirectory/deployment.json"
