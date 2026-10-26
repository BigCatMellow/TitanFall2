param([Parameter(Mandatory)][string]$BatchDirectory,[Parameter(Mandatory)][string]$ValidationDirectory,[Parameter(Mandatory)][string]$ReadinessRetestDirectory,
    [string]$TestProfile='C:\Users\james\northstar-crash-audit\map-cycle-test-profile',
    [string]$GameDirectory='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2',
    [string]$RepositoryRoot=(Split-Path $PSScriptRoot),[string]$ResumeBatch,[switch]$ObserverDefaults)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
$validation=Get-Content -Raw -LiteralPath "$ValidationDirectory/progress.json"|ConvertFrom-Json
if($validation.state-ne'passed'-or$validation.dedicated){throw 'Require completed client/transition/lobby integration checks before this listen-server survey'}
$validated=Get-Content -Raw -LiteralPath "$ValidationDirectory/processes.json"|ConvertFrom-Json
if(($validation.completed-join',')-ne'0,1,2,3,4,6'){throw 'Full native integration coverage is required'}
$retest=Get-Content -Raw -LiteralPath "$ReadinessRetestDirectory/progress.json"|ConvertFrom-Json
$retestBuild=Get-Content -Raw -LiteralPath "$ReadinessRetestDirectory/processes.json"|ConvertFrom-Json
if($retest.state-ne'passed'-or-not$retest.quick-or$retestBuild.dll_sha256-ne$validated.dll_sha256){throw 'Final readiness retest did not pass with the same native build'}
if((Get-FileHash -LiteralPath "$TestProfile/mods/James.BotDecisions/mod/scripts/vscripts/james_bot_decisions.nut").Hash-ne$retestBuild.bridge_sha256){throw 'Bridge differs from the tested final readiness script'}
if((Get-FileHash -LiteralPath "$TestProfile/plugins/bp_ort.dll").Hash-ne$validated.dll_sha256){throw 'Profile DLL differs from the validated candidate'}
if(Test-Path -LiteralPath $BatchDirectory){throw 'Preserve the previous batch; create a fresh directory'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game is already running'}
New-Item -ItemType Directory -Path "$BatchDirectory/backup" -Force|Out-Null
$cfg="$TestProfile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
$enabled="$TestProfile/enabledmods.json"
$surveyDir="$TestProfile/mods/James.MapSurvey"
$surveyScript="$surveyDir/mod/scripts/vscripts/james_map_survey.nut"
$hadManifest=Test-Path -LiteralPath "$surveyDir/mod.json"
Copy-Item -LiteralPath $cfg -Destination "$BatchDirectory/backup/server.cfg"
Copy-Item -LiteralPath $enabled -Destination "$BatchDirectory/backup/enabledmods.json"
if(Test-Path -LiteralPath $surveyScript){Copy-Item -LiteralPath $surveyScript -Destination "$BatchDirectory/backup/survey.nut"}
if($hadManifest){Copy-Item -LiteralPath "$surveyDir/mod.json" -Destination "$BatchDirectory/backup/survey-mod.json"}
$sourceScript="$repo/automation/runtime-mods/map-cycle-test-profile/James.MapSurvey/mod/scripts/vscripts/james_map_survey.nut"
$template=Get-Content -Raw -LiteralPath $sourceScript
if([regex]::Matches($template,'array<string> maps = \[[^\r\n]+\]').Count-ne1){throw 'Unexpected survey template map declaration'}
$oldPlan=Get-Content -Raw -LiteralPath "$repo/Notes/map-surveys/all-maps-20261025-102025/plan.json"|ConvertFrom-Json
$priority=@('mp_forwardbase_kodai','mp_grave','mp_homestead','mp_relic02','mp_rise','mp_thaw','mp_wargames','mp_eden','mp_glitch','mp_angel_city')
$maps=@($priority)+@($oldPlan.maps|Where-Object {$_-notin$priority})
$completedPreviously=@()
if($ResumeBatch){
    $previous=Get-Content -Raw -LiteralPath "$ResumeBatch/status.json"|ConvertFrom-Json
    $previousPlan=Get-Content -Raw -LiteralPath "$ResumeBatch/plan.json"|ConvertFrom-Json
    if($previous.state-notin@('stopped_error','stopped_by_request')){throw 'Resume only a stopped batch'}
    if($previousPlan.dll_sha256-ne$validated.dll_sha256-or$previousPlan.bridge_sha256-ne$retestBuild.bridge_sha256-or$previousPlan.core_sha256-ne(Get-FileHash "$TestProfile/Northstar.dll").Hash){throw 'Cannot resume across changed runtime builds'}
    $completedPreviously=@($previous.results|Where-Object {$_.result.valid-eq'true'}|ForEach-Object {$_.map})
    $maps=@($previousPlan.maps|Where-Object {$_-notin$completedPreviously})
    if(-not$maps.Count){throw 'No remaining maps to resume'}
}
$dllHash=(Get-FileHash -LiteralPath "$TestProfile/plugins/bp_ort.dll").Hash
$coreHash=(Get-FileHash -LiteralPath "$TestProfile/Northstar.dll").Hash
$bridge="$TestProfile/mods/James.BotDecisions/mod/scripts/vscripts/james_bot_decisions.nut"
$bridgeHash=(Get-FileHash -LiteralPath $bridge).Hash
$plan=[ordered]@{created=(Get-Date).ToString('o');build='decisions-v18';dll_sha256=$dllHash;core_sha256=$coreHash;bridge_sha256=$bridgeHash;maps=$maps;excluded_maps=$oldPlan.excluded_maps;bots=16;observer=1;goal=200;minutes=15;aim=0.78;kind='Fresh-process listen-server candidate cohort; not mixed with v16';validation=$ValidationDirectory;readiness_retest=$ReadinessRetestDirectory}
$plan.resumed_from=$ResumeBatch;$plan.completed_previously=$completedPreviously
$plan.observer_loadout_restore=-not[bool]$ObserverDefaults
$plan|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$BatchDirectory/plan.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');current=$null;planned=$maps.Count;results=@();failure=$null}
function Save-State {
    $state.updated=(Get-Date).ToString('o')
    $state|ConvertTo-Json -Depth 7|Set-Content -LiteralPath "$BatchDirectory/status.tmp"
    Move-Item -LiteralPath "$BatchDirectory/status.tmp" -Destination "$BatchDirectory/status.json" -Force
}
function Fields($line){$f=@{};foreach($m in [regex]::Matches($line,'(?:^|\s)([a-z_]+)=([^\s]+)')){$f[$m.Groups[1].Value]=$m.Groups[2].Value};$f}
function Stop-Owned($process){
    if(-not$process){return}
    $p=Get-CimInstance Win32_Process -Filter "ProcessId=$($process.Id)" -ErrorAction SilentlyContinue
    if($p-and$p.Name-eq'NorthstarLauncher.exe'-and$p.CommandLine-and$p.CommandLine.Contains("-profile=$TestProfile")){
        Stop-Process -Id $p.ProcessId -Force;[void]$process.WaitForExit(15000)
        # Process enumeration can briefly retain an exited process after kill.
        $deadline=(Get-Date).AddSeconds(10)
        while((Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue)-and(Get-Date)-lt$deadline){Start-Sleep -Milliseconds 250}
    }
}
$process=$null;$reader=$null
try{
    New-Item -ItemType Directory -Path (Split-Path $surveyScript) -Force|Out-Null
    Copy-Item -LiteralPath "$repo/automation/runtime-mods/survey/James.MapSurvey/mod.json" -Destination "$surveyDir/mod.json" -Force
    $mods=Get-Content -Raw -LiteralPath $enabled|ConvertFrom-Json -AsHashtable
    foreach($name in @('James.DecisionTest','James.BotCycleTest','James.MenuPreviewTest')){
        if($mods.ContainsKey($name)){foreach($version in @($mods[$name].Keys)){$mods[$name][$version]=$false}}
    }
    $mods['James.MapSurvey']=@{'1.0.0'=$true};$mods['James.BotDecisions']=@{'1.0.0'=$true}
    $mods|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $enabled
    $text=Get-Content -Raw -LiteralPath "$BatchDirectory/backup/server.cfg"
    $text=$text.Replace('bot_manager_max 16','bot_manager_max 17').Replace('bot_manager_target 16','bot_manager_target 17')
    $text=[regex]::Replace($text,'(?m)^setplaylistvaroverrides .*$', 'setplaylistvaroverrides "max_players 17 timelimit 15 scorelimit 200"')
    $text+="`r`nns_allow_spectators 1`r`nns_should_return_to_lobby 0`r`nbot_navigation_context 1`r`nbot_target_eligibility 1`r`nbot_action_policy 1`r`nbot_step_retry 1`r`n"
    if($ObserverDefaults){$text+="james_local_loadouts 0 // survey observer only; preserve saved files without restoring them`r`n"}
    Set-Content -LiteralPath $cfg -Value $text
    $index=0
    foreach($map in $maps){
        if(Test-Path -LiteralPath "$BatchDirectory/stop-after-current.txt"){$state.state='stopped_by_request';break}
        if($map-notmatch'^mp_[a-z0-9_]+$'){throw 'Invalid planned map identifier'}
        if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared; queue will not replace it'}
        if((Get-FileHash "$TestProfile/plugins/bp_ort.dll").Hash-ne$dllHash-or(Get-FileHash "$TestProfile/Northstar.dll").Hash-ne$coreHash-or(Get-FileHash $bridge).Hash-ne$bridgeHash){throw 'Frozen runtime changed; stop instead of mixing builds'}
        $index++;$dir=Join-Path $BatchDirectory ('{0:D2}-{1}'-f$index,$map)
        New-Item -ItemType Directory -Path $dir|Out-Null
        $one=[regex]::Replace($template,'array<string> maps = \[[^\r\n]+\]',('array<string> maps = ["'+$map+'"]'))
        [IO.File]::WriteAllText($surveyScript,$one,[Text.UTF8Encoding]::new($false))
        $state.state='starting';$state.current=@{map=$map;index=$index;directory=$dir};Save-State
        $began=Get-Date;$seen=@(Get-ChildItem "$TestProfile/logs" -Filter 'nslog*.txt'|Select-Object -ExpandProperty Name)
        $process=Start-Process -FilePath "$GameDirectory/NorthstarLauncher.exe" -WorkingDirectory $GameDirectory -WindowStyle Normal -PassThru -ArgumentList "-profile=$TestProfile",'-novid','-fullscreen','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 17 scorelimit 200 timelimit 15"','+james_survey_goal','200','+james_survey_count','1','+james_survey_index','0','+james_survey_minutes','15','+james_survey_smoke','0','+mp_gamemode','tdm','+map',$map
        $state.current.pid=$process.Id;Save-State
        $log=$null;$lastHeartbeat=Get-Date;$result=$null;$done=$false
        while(-not$done){
            if(-not$log){
                $log=Get-ChildItem "$TestProfile/logs" -Filter 'nslog*.txt'|Where-Object Name -notin $seen|Sort-Object CreationTime -Descending|Select-Object -First 1
                if($log){$stream=[IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);$state.current.log=$log.FullName}
            }
            if($reader){while($null-ne($line=$reader.ReadLine())){
                if($line-match'NorthstarLauncher version:\s+(\S+)' -and $Matches[1]-ne'1.31.14.0'){throw 'Wrong actual core version'}
                if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|\[error\]'){throw "Game error: $line"}
                if($line.Contains('MAP_SURVEY_BEGIN ')){
                    $f=Fields $line;if($f.bots-ne'16'-or$f.imc-ne'8'-or$f.militia-ne'8'-or$f.observer_alive-ne'0'){throw 'Uncontrolled survey population'}
                    $state.state='running';$lastHeartbeat=Get-Date
                }
                if($line.Contains('MAP_SURVEY_SCORE ')){$state.current.score=Fields $line;$lastHeartbeat=Get-Date;Save-State}
                if($line.Contains('MAP_SURVEY_RESULT ')){$result=Fields $line;if($result.valid-ne'true'){throw 'Invalid match result'}}
                if($line.Contains('MAP_SURVEY_DONE ')){$done=$true}
            }}
            $process.Refresh();if($process.HasExited-and-not$done){throw 'Survey game exited early'}
            if((Get-Date)-$lastHeartbeat-gt[TimeSpan]::FromMinutes(4)){throw 'No survey heartbeat for four minutes'}
            if((Get-Date)-$began-gt[TimeSpan]::FromMinutes(20)){throw 'Map exceeded wall-clock limit'}
            if(-not$done){Start-Sleep -Seconds 1}
        }
        if(-not$result){throw 'Missing completed match result'}
        $reader.Dispose();$reader=$null;Start-Sleep -Seconds 2;Stop-Owned $process;$process=$null
        Copy-Item -LiteralPath $log.FullName -Destination "$dir/raw-session.log"
        $result|ConvertTo-Json|Set-Content -LiteralPath "$dir/result.json"
        $reportError=$null
        try{
            & "$repo/Notes/tools/Export-BotSession.ps1" -LogPath "$dir/raw-session.log" -OutputDirectory "$dir/movement"|Out-Null
            & "$repo/Notes/tools/Export-CombatDecisions.ps1" -LogPath "$dir/raw-session.log" -OutputDirectory "$dir/combat"|Out-Null
        }catch{$reportError=[string]$_}
        $state.results+=@{map=$map;result=$result;directory=$dir;report_error=$reportError};$state.state='between_maps';Save-State
    }
    if($state.state-ne'stopped_by_request'){$state.state='complete'}
}catch{
    $state.state='stopped_error';$state.failure=[string]$_
    if($log -and $dir -and (Test-Path -LiteralPath $log.FullName)){Copy-Item -LiteralPath $log.FullName -Destination "$dir/raw-session.log" -Force}
}
finally{
    if($reader){$reader.Dispose()};Stop-Owned $process
    if(-not(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
        Copy-Item -LiteralPath "$BatchDirectory/backup/server.cfg" -Destination $cfg -Force
        Copy-Item -LiteralPath "$BatchDirectory/backup/enabledmods.json" -Destination $enabled -Force
        if(Test-Path "$BatchDirectory/backup/survey.nut"){Copy-Item "$BatchDirectory/backup/survey.nut" $surveyScript -Force}
        if($hadManifest){Copy-Item "$BatchDirectory/backup/survey-mod.json" "$surveyDir/mod.json" -Force}
        elseif(Test-Path "$surveyDir/mod.json"){Move-Item -LiteralPath "$surveyDir/mod.json" -Destination "$BatchDirectory/survey-mod.json" -Force}
        $state.profile_restored=$true
    }else{$state.profile_restored=$false;$state.failure+='; game still running, did not edit loaded profile files'}
    Save-State
}
