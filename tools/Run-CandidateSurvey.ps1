param([Parameter(Mandatory)][string]$BatchDirectory,[Parameter(Mandatory)][string]$ValidationDirectory,[Parameter(Mandatory)][string]$ReadinessRetestDirectory,
    [string]$TestProfile="$env:USERPROFILE\northstar-crash-audit\map-cycle-test-profile",
    [string]$GameDirectory='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2',
    [string]$RepositoryRoot=(Split-Path $PSScriptRoot),[string]$ResumeBatch,[switch]$ObserverDefaults,
    [ValidateRange(1,9999)][int]$Goal=200,[string[]]$MapNames,[switch]$ValidatedV20,
    [switch]$NavigationV22,[ValidateRange(0,1)][int]$CornerGuard=0,
    [switch]$RouteStudy,[ValidateRange(0,1)][int]$RouteVariant=0,[switch]$IntegrationV28,
    [ValidateSet('baseline','nearest_baseline','nearest','stall','frag','clearance','height','combined')][string]$IntegrationCell='baseline')
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
$repo=(Resolve-Path -LiteralPath $RepositoryRoot).Path
if($IntegrationV28){
    if($RouteStudy-or$NavigationV22-or$ValidatedV20){throw 'Separate integration cohort required'}
    . "$PSScriptRoot/Read-IntegrationValidation.ps1"
    . "$PSScriptRoot/Integration-Cells.ps1"
    $validated=Read-IntegrationValidation $ValidationDirectory $TestProfile
    $retestBuild=[pscustomobject]@{bridge_sha256=$validated.bridge_sha256}
    $integrationExpected=Get-IntegrationCell $IntegrationCell
    $integrationVars=Get-IntegrationConVars
}elseif($RouteStudy){
    if($NavigationV22-or$ValidatedV20){throw 'Choose one study cohort'}
    . "$PSScriptRoot/Read-RouteStudyValidation.ps1"
    $validated=Read-RouteStudyValidation $ValidationDirectory $TestProfile
    $retestBuild=[pscustomobject]@{bridge_sha256=$validated.bridge_sha256}
}elseif($NavigationV22){
    if($ValidatedV20){throw 'Choose one validation cohort'}
    . "$PSScriptRoot/Read-CornerValidation.ps1"
    $validated=Read-CornerValidation $ValidationDirectory $TestProfile
    $retestBuild=[pscustomobject]@{bridge_sha256=$validated.bridge_sha256}
}elseif($ValidatedV20){
    $receipt=Get-Content "$TestProfile/bt7274-candidate.json" -Raw|ConvertFrom-Json
    $expected='3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89'
    $expectedBridge='9C43719868D28121E6D59A07C3317882E135A50FF3C91AA1340A12C1219C4598'
    if($receipt.state-ne'validated_for_playtest'-or$receipt.native_sha256-ne$expected-or$receipt.compatibility-ne'passed'-or$receipt.staged_smoke-ne'passed'){throw 'Require the installed Windows-tested v20 receipt'}
    if((Get-FileHash "$TestProfile/plugins/bp_ort.dll").Hash-ne$expected-or(Get-FileHash "$TestProfile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash-ne$expectedBridge){throw 'Validated v20 DLL/bridge mismatch'}
    if((Get-Item "$TestProfile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'Wrong v20 core'}
    $validated=[pscustomobject]@{dll_sha256=$expected};$retestBuild=[pscustomobject]@{bridge_sha256=$expectedBridge}
}else{
$validation=Get-Content -Raw -LiteralPath "$ValidationDirectory/progress.json"|ConvertFrom-Json
if($validation.state-ne'passed'-or$validation.dedicated){throw 'Require completed client/transition/lobby integration checks before this listen-server survey'}
$validated=Get-Content -Raw -LiteralPath "$ValidationDirectory/processes.json"|ConvertFrom-Json
if(($validation.completed-join',')-ne'0,1,2,3,4,6'){throw 'Full native integration coverage is required'}
$retest=Get-Content -Raw -LiteralPath "$ReadinessRetestDirectory/progress.json"|ConvertFrom-Json
$retestBuild=Get-Content -Raw -LiteralPath "$ReadinessRetestDirectory/processes.json"|ConvertFrom-Json
if($retest.state-ne'passed'-or-not$retest.quick-or$retestBuild.dll_sha256-ne$validated.dll_sha256){throw 'Final readiness retest did not pass with the same native build'}
if((Get-FileHash -LiteralPath "$TestProfile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash-ne$retestBuild.bridge_sha256){throw 'Bridge differs from the tested final readiness script'}
if((Get-FileHash -LiteralPath "$TestProfile/plugins/bp_ort.dll").Hash-ne$validated.dll_sha256){throw 'Profile DLL differs from the validated candidate'}
}
if(Test-Path -LiteralPath $BatchDirectory){throw 'Preserve the previous batch; create a fresh directory'}
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game is already running'}
New-Item -ItemType Directory -Path "$BatchDirectory/backup" -Force|Out-Null
$cfg="$TestProfile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg"
$enabled="$TestProfile/enabledmods.json"
$surveyDir="$TestProfile/mods/BT7274.MapSurvey"
$surveyScript="$surveyDir/mod/scripts/vscripts/bt7274_map_survey.nut"
$hadManifest=Test-Path -LiteralPath "$surveyDir/mod.json"
Copy-Item -LiteralPath $cfg -Destination "$BatchDirectory/backup/server.cfg"
Copy-Item -LiteralPath $enabled -Destination "$BatchDirectory/backup/enabledmods.json"
if(Test-Path -LiteralPath $surveyScript){Copy-Item -LiteralPath $surveyScript -Destination "$BatchDirectory/backup/survey.nut"}
if($hadManifest){Copy-Item -LiteralPath "$surveyDir/mod.json" -Destination "$BatchDirectory/backup/survey-mod.json"}
$sourceScript="$repo/automation/runtime-mods/map-cycle-test-profile/BT7274.MapSurvey/mod/scripts/vscripts/bt7274_map_survey.nut"
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
if($MapNames){
    if($ResumeBatch){throw 'Use either explicit maps or resume selection'}
    foreach($requested in $MapNames){if($requested-notin$maps){throw "Unsupported survey map: $requested"}}
    $maps=@($MapNames|Select-Object -Unique)
}
$dllHash=(Get-FileHash -LiteralPath "$TestProfile/plugins/bp_ort.dll").Hash
$coreHash=(Get-FileHash -LiteralPath "$TestProfile/Northstar.dll").Hash
$bridge="$TestProfile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut"
$bridgeHash=(Get-FileHash -LiteralPath $bridge).Hash
$plan=[ordered]@{created=(Get-Date).ToString('o');build='decisions-v18';dll_sha256=$dllHash;core_sha256=$coreHash;bridge_sha256=$bridgeHash;maps=$maps;excluded_maps=$oldPlan.excluded_maps;bots=16;observer=1;goal=$Goal;minutes=15;aim=0.78;kind='Fresh-process listen-server candidate cohort; not mixed with v16';validation=$ValidationDirectory;readiness_retest=$ReadinessRetestDirectory}
$plan.resumed_from=$ResumeBatch;$plan.completed_previously=$completedPreviously
if($ValidatedV20){$plan.build='bot-capability-v20-Full';$plan.kind='Unattended v20 Full; separate from played sessions and historical v18';$plan.validation='Installed v20 receipt plus exact frozen DLL/core/bridge checks'}
if($NavigationV22){$plan.build='nav-corner-v22';$plan.kind='Navigation A/B, same native build; no v21 safety/retarget';$plan.corner_guard=$CornerGuard;$plan.validation=$ValidationDirectory}
if($RouteStudy){$plan.build='routing-v24-study-v23-native';$plan.kind='Paired global routing trial against installed Eden-only behavior; read-only weapon/frag measurement';$plan.route_variant=$RouteVariant;$plan.measurement_sha256=$validated.measurement_sha256}
$plan.observer_loadout_restore=-not[bool]$ObserverDefaults
if($IntegrationV28){$plan.build='integration-v28';$plan.kind='Frozen integrated native, independently switched cell';$plan.integration_cell=$IntegrationCell;$plan.integration_settings=$integrationExpected;$plan.measurement_sha256=$validated.measurement_sha256;$plan.damage_probe_sha256=$validated.damage_probe_sha256}
$plan|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$BatchDirectory/plan.json"
$state=[ordered]@{state='preparing';started=(Get-Date).ToString('o');current=$null;planned=$maps.Count;results=@();failure=$null}
function Save-State {
    $state.updated=(Get-Date).ToString('o')
    $state|ConvertTo-Json -Depth 7|Set-Content -LiteralPath "$BatchDirectory/status.tmp"
    Move-Item -LiteralPath "$BatchDirectory/status.tmp" -Destination "$BatchDirectory/status.json" -Force
}
function Fields($line){$f=@{};foreach($m in [regex]::Matches($line,'(?:^|\s)([a-z_]+)=([^\s]+)')){$f[$m.Groups[1].Value]=$m.Groups[2].Value};$f}
function Stop-Owned($process){
    Stop-OwnedSurveyGame -Process $process -Profile $TestProfile
}
$process=$null;$reader=$null
try{
    New-Item -ItemType Directory -Path (Split-Path $surveyScript) -Force|Out-Null
    Copy-Item -LiteralPath "$repo/automation/runtime-mods/survey/BT7274.MapSurvey/mod.json" -Destination "$surveyDir/mod.json" -Force
    $mods=Get-Content -Raw -LiteralPath $enabled|ConvertFrom-Json -AsHashtable
    foreach($name in @('BT7274.DecisionTest','BT7274.BotCycleTest','BT7274.MenuPreviewTest','BT7274.CapabilityTest','BT7274.WeaponIntegrationTest','BT7274.SafetyTest','BT7274.RouteProbe','BT7274.PulseTrial')){
        if($mods.ContainsKey($name)){foreach($version in @($mods[$name].Keys)){$mods[$name][$version]=$false}}
    }
    $mods['BT7274.MapSurvey']=@{'1.0.0'=$true};$mods['BT7274.BotDecisions']=@{'1.0.0'=$true}
    if($RouteStudy-or$IntegrationV28){$mods['BT7274.BotMeasurements']=@{'1.0.0'=$true}}
    if($IntegrationV28){$mods['BT7274.FragDamageProbe']=@{'0.1.0'=$true}}
    $mods|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $enabled
    $text=Get-Content -Raw -LiteralPath "$BatchDirectory/backup/server.cfg"
    $text=$text.Replace('bot_manager_max 16','bot_manager_max 17').Replace('bot_manager_target 16','bot_manager_target 17')
    $text=[regex]::Replace($text,'(?m)^setplaylistvaroverrides .*$', ('setplaylistvaroverrides "max_players 17 timelimit 15 scorelimit '+$Goal+'"'))
    $text+="`r`nns_allow_spectators 1`r`nns_should_return_to_lobby 0`r`nbot_navigation_context 1`r`nbot_target_eligibility 1`r`nbot_action_policy 1`r`nbot_step_retry 1`r`n"
    if($ObserverDefaults){$text+="bt7274_local_loadouts 0 // survey observer only; preserve saved files without restoring them`r`n"}
    if($NavigationV22){$text+="bot_offhand_safety 0`r`nbot_stall_retarget 0`r`nbot_corner_height_guard $CornerGuard`r`n"}
    if($RouteStudy){$text+="bot_eden_route_repair 1`r`nbot_route_continuity $RouteVariant`r`nbot_link_detour $RouteVariant`r`nbot_corner_height_guard 0`r`nbot_offhand_safety 0`r`nbot_stall_retarget 0`r`nbot_telemetry_interval 1`r`nsolo_notes_mode controlled_validation`r`nbt7274_bot_measurements 1`r`n"}
    if($IntegrationV28){
        $text+="`nns_auth_allow_insecure 1`nbot_telemetry_interval 1`nsolo_notes_mode controlled_validation`n"
        foreach($key in $integrationExpected.Keys){$text+=$integrationVars[$key]+' '+$integrationExpected[$key]+"`n"}
    }
    Set-Content -LiteralPath $cfg -Value $text
    $index=0
    foreach($map in $maps){
        if(Test-Path -LiteralPath "$BatchDirectory/stop-after-current.txt"){$state.state='stopped_by_request';break}
        if($map-notmatch'^mp_[a-z0-9_]+$'){throw 'Invalid planned map identifier'}
        if($RouteStudy-and!(Get-ChildItem "$GameDirectory/vpk" -Filter "*_$map.bsp.pak000_dir.vpk" -File)){throw 'Missing installed map assets'}
        if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared; queue will not replace it'}
        if((Get-FileHash "$TestProfile/plugins/bp_ort.dll").Hash-ne$dllHash-or(Get-FileHash "$TestProfile/Northstar.dll").Hash-ne$coreHash-or(Get-FileHash $bridge).Hash-ne$bridgeHash){throw 'Frozen runtime changed; stop instead of mixing builds'}
        $index++;$dir=Join-Path $BatchDirectory ('{0:D2}-{1}'-f$index,$map)
        New-Item -ItemType Directory -Path $dir|Out-Null
        $one=[regex]::Replace($template,'array<string> maps = \[[^\r\n]+\]',('array<string> maps = ["'+$map+'"]'))
        if($NavigationV22){
            $marker='(?m)^(\s*print\( "MAP_SURVEY_BEGIN[^\r\n]+)$'
            if([regex]::Matches($one,$marker).Count-ne1){throw 'Unexpected survey begin marker'}
            $one=[regex]::Replace($one,$marker,('$1'+"`n"+'    print("MAP_SURVEY_CORNER_GUARD value="+GetConVarInt("bot_corner_height_guard")+" safety="+GetConVarBool("bot_offhand_safety")+" retarget="+GetConVarBool("bot_stall_retarget"))'))
        }
        if($RouteStudy){
            $marker='(?m)^(\s*print\( "MAP_SURVEY_BEGIN[^\r\n]+)$'
            if([regex]::Matches($one,$marker).Count-ne1){throw 'Unexpected survey begin marker'}
            $one=[regex]::Replace($one,$marker,('$1'+"`n"+'    print("MAP_SURVEY_ROUTE t="+Time()+" variant='+$RouteVariant+' continuity="+GetConVarInt("bot_route_continuity")+" detour="+GetConVarInt("bot_link_detour")+" eden="+GetConVarInt("bot_eden_route_repair")+" measurements="+GetConVarInt("bt7274_bot_measurements")+" safety="+GetConVarBool("bot_offhand_safety")+" retarget="+GetConVarBool("bot_stall_retarget"))'))
        }
        if($IntegrationV28){
            $marker='(?m)^(\s*print\( "MAP_SURVEY_BEGIN[^\r\n]+)$'
            if([regex]::Matches($one,$marker).Count-ne1){throw 'Unexpected integration survey marker'}
            $readback='    print("MAP_SURVEY_INTEGRATION t="+Time()+" cell='+$IntegrationCell+'"'
            foreach($key in $integrationExpected.Keys){$readback+='+" '+$key+'="+GetConVarInt("'+$integrationVars[$key]+'")'}
            $readback+=')'
            $one=[regex]::Replace($one,$marker,('$1'+"`n"+$readback))
        }
        [IO.File]::WriteAllText($surveyScript,$one,[Text.UTF8Encoding]::new($false))
        $state.state='starting';$state.current=@{map=$map;index=$index;directory=$dir};Save-State
        $began=Get-Date;$seen=@(Get-ChildItem "$TestProfile/logs" -Filter 'nslog*.txt'|Select-Object -ExpandProperty Name)
        $windowMode=if($NavigationV22-or$RouteStudy-or$IntegrationV28){'-windowed'}else{'-fullscreen'}
        $process=Start-Process -FilePath "$GameDirectory/NorthstarLauncher.exe" -WorkingDirectory $GameDirectory -WindowStyle Hidden -PassThru -ArgumentList "-profile=$TestProfile",'-novid',$windowMode,'-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides',('"max_players 17 scorelimit '+$Goal+' timelimit 15"'),'+bt7274_survey_goal',"$Goal",'+bt7274_survey_count','1','+bt7274_survey_index','0','+bt7274_survey_minutes','15','+bt7274_survey_smoke','0','+mp_gamemode','tdm','+map',$map
        $state.current.pid=$process.Id;Save-State
        $log=$null;$lastHeartbeat=Get-Date;$result=$null;$done=$false;$cornerStateSeen=$false;$routeStateSeen=$false
        while(-not$done){
            if(-not$log){
                $log=Get-ChildItem "$TestProfile/logs" -Filter 'nslog*.txt'|Where-Object Name -notin $seen|Sort-Object CreationTime -Descending|Select-Object -First 1
                if($log){$stream=[IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);$state.current.log=$log.FullName}
            }
            if($reader){while($null-ne($line=$reader.ReadLine())){
                if($line-match'NorthstarLauncher version:\s+(\S+)' -and $Matches[1]-ne'1.31.14.0'){throw 'Wrong actual core version'}
                if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_MEASURE_ERROR|BT_FRAG_DAMAGE_ERROR|BT_FRAG_PROBE_ERROR|\[error\]'){throw "Game error: $line"}
                if($line.Contains('MAP_SURVEY_BEGIN ')){
                    $f=Fields $line;if($f.bots-ne'16'-or$f.imc-ne'8'-or$f.militia-ne'8'-or$f.observer_alive-ne'0'){throw 'Uncontrolled survey population'}
                    if([int]$f.goal-ne$Goal-or[int]$f.engine_goal-ne$Goal){throw 'Engine and harness score goals do not match the requested trial'}
                    $state.state='running';$lastHeartbeat=Get-Date
                }
                if($line.Contains('MAP_SURVEY_SCORE ')){$state.current.score=Fields $line;$lastHeartbeat=Get-Date;Save-State}
                if($NavigationV22-and$line.Contains('MAP_SURVEY_CORNER_GUARD ')){
                    $f=Fields $line
                    if([int]$f.value-ne$CornerGuard-or$f.safety-ne'false'-or$f.retarget-ne'false'){throw 'Unexpected corner/safety switches'}
                    $cornerStateSeen=$true
                }
                if($RouteStudy-and$line.Contains('MAP_SURVEY_ROUTE ')){
                    $f=Fields $line
                    if([int]$f.variant-ne$RouteVariant-or[int]$f.continuity-ne$RouteVariant-or[int]$f.detour-ne$RouteVariant-or$f.eden-ne'1'-or$f.measurements-ne'1'-or$f.safety-ne'false'-or$f.retarget-ne'false'){throw 'Unexpected routing study switches'}
                    $routeStateSeen=$true
                }
                if($IntegrationV28-and$line.Contains('MAP_SURVEY_INTEGRATION ')){
                    $f=Fields $line;if($f.cell-ne$IntegrationCell){throw 'Wrong integration cell'}
                    foreach($key in $integrationExpected.Keys){if($f[$key]-ne[string]$integrationExpected[$key]){throw "Wrong integration switches $key"}}
                    $routeStateSeen=$true
                }
                if($line.Contains('MAP_SURVEY_RESULT ')){$result=Fields $line;if($result.valid-ne'true'){throw 'Invalid match result'};if($NavigationV22-and-not$cornerStateSeen){throw 'Missing corner variant confirmation'}}
                if($line.Contains('MAP_SURVEY_DONE ')){$done=$true}
            }}
            $process.Refresh();if($process.HasExited-and-not$done){throw 'Survey game exited early'}
            if((Get-Date)-$lastHeartbeat-gt[TimeSpan]::FromMinutes(4)){throw 'No survey heartbeat for four minutes'}
            if((Get-Date)-$began-gt[TimeSpan]::FromMinutes(20)){throw 'Map exceeded wall-clock limit'}
            if(-not$done){Start-Sleep -Seconds 1}
        }
        if(-not$result){throw 'Missing completed match result'}
        if(($RouteStudy-or$IntegrationV28)-and-not$routeStateSeen){throw 'Missing routing variant readback'}
        # Persist the completed match before shutdown, so cleanup cannot erase it.
        Copy-Item -LiteralPath $log.FullName -Destination "$dir/raw-session.log"
        $result|ConvertTo-Json|Set-Content -LiteralPath "$dir/result.json"
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
    if($reader){$reader.Dispose()}
    try{Stop-Owned $process}catch{$state.state='stopped_error';$state.failure+='; cleanup: '+[string]$_}
    try{
    if(-not(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue|Where-Object {-not$_.HasExited})){
        Copy-Item -LiteralPath "$BatchDirectory/backup/server.cfg" -Destination $cfg -Force
        Copy-Item -LiteralPath "$BatchDirectory/backup/enabledmods.json" -Destination $enabled -Force
        if(Test-Path "$BatchDirectory/backup/survey.nut"){Copy-Item "$BatchDirectory/backup/survey.nut" $surveyScript -Force}
        if($hadManifest){Copy-Item "$BatchDirectory/backup/survey-mod.json" "$surveyDir/mod.json" -Force}
        elseif(Test-Path "$surveyDir/mod.json"){Move-Item -LiteralPath "$surveyDir/mod.json" -Destination "$BatchDirectory/survey-mod.json" -Force}
        $state.profile_restored=$true
    }else{$state.profile_restored=$false;$state.failure+='; game still running, did not edit loaded profile files'}
    }catch{$state.state='stopped_error';$state.profile_restored=$false;$state.failure+='; restore: '+[string]$_}
    Save-State
}
