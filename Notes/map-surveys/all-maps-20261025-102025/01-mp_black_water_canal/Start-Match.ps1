param([Parameter(Mandatory=$true)][string]$RootDirectory)
$ErrorActionPreference='Stop'
$audit="$env:USERPROFILE\northstar-crash-audit";$profile=Join-Path $audit 'map-cycle-test-profile';$game='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2'
$root=[IO.Path]::GetFullPath($RootDirectory);$allowed=Join-Path $audit 'Notes\map-surveys'
if(-not $root.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected survey directory'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close the existing game before starting the survey'}
$plan=Get-Content -Raw "$root\plan.json"|ConvertFrom-Json
if((Get-FileHash "$profile\plugins\bp_ort.dll").Hash-ne$plan.dll_sha256){throw 'Bot DLL differs from the frozen survey build'}
$run=Join-Path $root 'main';if(Test-Path "$run\progress.json"){throw 'This survey already has a main run; preserve it and create a new survey directory for a repeat'}
New-Item -ItemType Directory -Path $run -Force|Out-Null
Copy-Item -LiteralPath "$root\survey-one-map.nut" -Destination "$profile\mods\BT7274.MapSurvey\mod\scripts\vscripts\bt7274_map_survey.nut" -Force
$cfg=Join-Path $profile 'mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg'
$text=Get-Content -Raw "$root\backup\autoexec_ns_server.cfg"
$text=$text.Replace('bot_manager_max 16','bot_manager_max 17').Replace('bot_manager_target 16','bot_manager_target 17')
$text=[regex]::Replace($text,'(?m)^setplaylistvaroverrides .*$', 'setplaylistvaroverrides "max_players 17 timelimit 15 scorelimit 200"')
$text+="`r`n// Temporary unattended survey; restored by its watchdog.`r`nns_allow_spectators 1`r`nns_should_return_to_lobby 1`r`n"
[IO.File]::WriteAllText($cfg,$text,[Text.UTF8Encoding]::new($false))
$cycle="$profile\mods\BT7274.BotCycleTest\mod.json"
if(Test-Path $cycle){Rename-Item -LiteralPath $cycle -NewName 'mod.json.map-survey-disabled'}
if(-not(Test-Path "$profile\mods\BT7274.MapSurvey\mod.json")){Copy-Item -LiteralPath "$root\survey-mod.json" -Destination "$profile\mods\BT7274.MapSurvey\mod.json"}
Copy-Item -LiteralPath "$profile\mods\BT7274.MapSurvey\mod\scripts\vscripts\bt7274_map_survey.nut" -Destination "$root\survey-script.nut" -Force
Copy-Item -LiteralPath "$root\survey-persistence-readonly.nut" -Destination "$profile\mods\BT7274.LocalPersistence\mod\scripts\vscripts\bt7274_local_persistence.nut" -Force
foreach($json in Get-ChildItem "$root\backup\test-saves" -Filter '*.json') { Copy-Item -LiteralPath $json.FullName -Destination "$profile\save_data\BT7274.LocalPersistence" -Force }
Copy-Item -LiteralPath "$root\watcher-template.ps1" -Destination "$root\watcher.ps1" -Force
$gameProcess=Start-Process -FilePath "$game\NorthstarLauncher.exe" -WorkingDirectory $game -ArgumentList "-profile=$profile",'-novid','-fullscreen','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 17 scorelimit 200 timelimit 15"','+bt7274_survey_goal','200','+bt7274_survey_count','1','+bt7274_survey_index','0','+bt7274_survey_smoke','0','+mp_gamemode','tdm','+map','mp_black_water_canal' -WindowStyle Normal -PassThru
try{
    $hostExe=(Get-Process -Id $PID).Path
    $watch=Start-Process -FilePath $hostExe -ArgumentList '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',"$root\watcher.ps1",'-GameProcessId',([string]$gameProcess.Id),'-RunDirectory',$run,'-RootDirectory',$root -WindowStyle Hidden -RedirectStandardOutput "$run\watcher.stdout.log" -RedirectStandardError "$run\watcher.stderr.log" -PassThru
    @{game_pid=$gameProcess.Id;watcher_pid=$watch.Id;run=$run;started=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content "$run\processes.json"
    Get-Content "$run\processes.json"
}catch{Stop-Process -Id $gameProcess.Id -Force -ErrorAction SilentlyContinue;throw}
