param([string]$Profile="$env:USERPROFILE\northstar-crash-audit\map-cycle-test-profile",
    [string]$GameDirectory='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2',
    [string]$RunDirectory,[string]$RepositoryRoot=(Split-Path $PSScriptRoot),[string]$DllPath,[switch]$Dedicated,[switch]$Quick,[switch]$WeaponIntegration,[switch]$ForceMapBootstrap)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is already running; do not replace it'}
if(-not$RunDirectory){$RunDirectory=Join-Path (Split-Path $repo) ('Notes/candidates/decisions-v18-'+(Get-Date -Format yyyyMMdd-HHmmss))}
if(Test-Path -LiteralPath $RunDirectory){throw 'Preserve the prior test directory'}
if(-not(Test-Path -LiteralPath "$Profile/mods/BT7274.DecisionTest/mod.json")){throw 'Candidate test harness is missing'}
if(-not(Test-Path -LiteralPath "$Profile/Northstar.dll")-or(Get-Item -LiteralPath "$Profile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'The candidate profile must include its matching Northstar1.31.14 runtime; do not silently fall back to the older game-root DLL'}
$dll=if($DllPath){$DllPath}else{"$repo/target/x86_64-pc-windows-gnu/distribution/bp_ort.dll"}
if(-not(Test-Path -LiteralPath $dll)){throw 'Build candidate first'}
New-Item -ItemType Directory -Path $RunDirectory -Force|Out-Null
Copy-Item -LiteralPath $dll -Destination "$Profile/plugins/bp_ort.dll" -Force
$exe=Join-Path $GameDirectory 'NorthstarLauncher.exe'
$argsList=@("-profile=$Profile",'-bt7274_decision_test','-novid','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+ns_auth_allow_insecure','1','+ns_report_server_to_masterserver','0','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 17 scorelimit 9999 timelimit 30"','+bt7274_candidate_phase',$(if($Quick){'4'}else{'0'}))
$population=if($Dedicated){16}else{17}
$argsList+=@('+bot_manager_target',[string]$population,'+bot_manager_max',[string]$population)
if($Dedicated){$argsList=@('-dedicated')+$argsList+@('+bt7274_candidate_dedicated','1')}
else{$argsList=@('-fullscreen')+$argsList}
if($Quick){$argsList+=@('+bt7274_candidate_quick','1')}
if($WeaponIntegration){$argsList+=@('+bt7274_candidate_weapons','1')}
if($ForceMapBootstrap){$argsList+='-bt7274_force_map_bootstrap'}
$argsList+=@('+mp_gamemode','tdm','+map','mp_eden')
$game=Start-Process -FilePath $exe -WorkingDirectory $GameDirectory -ArgumentList $argsList -WindowStyle $(if($Dedicated){'Hidden'}else{'Normal'}) -PassThru
$watchArgs=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',"$repo/tools/Watch-DecisionTest.ps1",'-GameProcessId',$game.Id,'-Profile',$Profile,'-RunDirectory',$RunDirectory)
if($Dedicated){$watchArgs+='-Dedicated'}
if($Quick){$watchArgs+='-Quick'}
if($WeaponIntegration){$watchArgs+='-WeaponIntegration'}
$watch=Start-Process -FilePath (Get-Process -Id $PID).Path -WindowStyle Hidden -ArgumentList $watchArgs -RedirectStandardOutput "$RunDirectory/watcher.stdout.log" -RedirectStandardError "$RunDirectory/watcher.stderr.log" -PassThru
[ordered]@{game_pid=$game.Id;watcher_pid=$watch.Id;profile=$Profile;run=$RunDirectory;quick=[bool]$Quick;dll_sha256=(Get-FileHash -LiteralPath $dll).Hash;bridge_sha256=(Get-FileHash -LiteralPath "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash;started=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath "$RunDirectory/processes.json"
Get-Content -LiteralPath "$RunDirectory/processes.json"
