param([Parameter(Mandatory=$true)][string]$BatchDirectory)
$ErrorActionPreference='Stop'
$audit="$env:USERPROFILE\northstar-crash-audit"
$profile=Join-Path $audit 'map-cycle-test-profile'
$allowed=Join-Path $audit 'Notes\map-surveys'
$batch=[IO.Path]::GetFullPath($BatchDirectory)
if(-not $batch.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected batch path'}
$plan=Get-Content -Raw "$batch\plan.json"|ConvertFrom-Json
$template=$plan.template_control
$records=[Collections.Generic.List[object]]::new()
$state='starting';$current=$null;$failure=$null
function SaveStatus {
    $data=[ordered]@{state=$state;updated=(Get-Date).ToString('o');current=$current;planned=@($plan.maps);results=$records.ToArray();failure=$failure}
    $data|ConvertTo-Json -Depth 10|Set-Content "$batch\status.tmp"
    Move-Item -LiteralPath "$batch\status.tmp" -Destination "$batch\status.json" -Force
    $lines=@('# Fresh-process bot test batch','',('State: '+$state),('Updated: '+(Get-Date).ToString('o')),('Current: '+[string]$current),'','Each match: fresh game process, fixed v16, aim error 0.78, 16 bots / 8v8, dead observer, 200-point team target, 15-minute cap.','','| Map | State | Score | Seconds | Pilot stall samples | Quick target reversals |','|---|---|---|---:|---:|---:|')
    $lines+=@($records|ForEach-Object{'| {0} | {1} | {2} | {3} | {4}% | {5}% |' -f $_.map,$_.state,$_.score,$_.elapsed,$_.stall_percent,$_.quick_reversal_percent})
    if($failure){$lines+=@('',('Batch stopped: '+$failure))}
    $lines+=@('','Per-match directories contain logs, reports and restoration checks. Time-capped matches are not completed 200-point rounds. A fresh Eden pass cannot establish the cause of the previous Meadow-to-Eden FX error.')
    [IO.File]::WriteAllLines("$batch\Summary.md",$lines,[Text.UTF8Encoding]::new($false))
}
function RestoreFiles([string]$root){
    Copy-Item -LiteralPath "$root\backup\autoexec_ns_server.cfg" -Destination "$profile\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg" -Force
    Copy-Item -LiteralPath "$root\backup\cycle-mod.json" -Destination "$profile\mods\BT7274.BotCycleTest\mod.json" -Force
    Copy-Item -LiteralPath "$root\backup\persistence-server.nut" -Destination "$profile\mods\BT7274.LocalPersistence\mod\scripts\vscripts\bt7274_local_persistence.nut" -Force
    Copy-Item -LiteralPath "$root\backup\survey-harness.nut" -Destination "$profile\mods\BT7274.MapSurvey\mod\scripts\vscripts\bt7274_map_survey.nut" -Force
    foreach($f in Get-ChildItem "$root\backup\test-saves" -Filter '*.json'){Copy-Item -LiteralPath $f.FullName -Destination "$profile\save_data\BT7274.LocalPersistence" -Force}
    $disabled="$profile\mods\BT7274.BotCycleTest\mod.json.map-survey-disabled"
    if(Test-Path $disabled){Remove-Item -LiteralPath $disabled -Force}
    if(Test-Path "$profile\mods\BT7274.MapSurvey\mod.json"){Move-Item -LiteralPath "$profile\mods\BT7274.MapSurvey\mod.json" -Destination "$root\survey-mod.json" -Force}
}
function CheckRestored([string]$root){
    $pairs=@(
        @('autoexec_ns_server.cfg','mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg'),
        @('cycle-mod.json','mods\BT7274.BotCycleTest\mod.json'),
        @('persistence-server.nut','mods\BT7274.LocalPersistence\mod\scripts\vscripts\bt7274_local_persistence.nut'),
        @('survey-harness.nut','mods\BT7274.MapSurvey\mod\scripts\vscripts\bt7274_map_survey.nut'))
    $checks=@(foreach($pair in $pairs){[pscustomobject]@{file=$pair[0];matches=(Get-FileHash "$root\backup\$($pair[0])").Hash -eq (Get-FileHash "$profile\$($pair[1])").Hash}})
    $checks+=@(foreach($f in Get-ChildItem "$root\backup\test-saves" -Filter '*.json'){[pscustomobject]@{file=$f.Name;matches=(Get-FileHash $f.FullName).Hash -eq (Get-FileHash "$profile\save_data\BT7274.LocalPersistence\$($f.Name)").Hash}})
    $checks+=[pscustomobject]@{file='survey disabled';matches=-not(Test-Path "$profile\mods\BT7274.MapSurvey\mod.json")}
    $checks+=[pscustomobject]@{file='normal save unchanged';matches=(Get-FileHash "$audit\local-test-profile\save_data\BT7274.LocalPersistence\loadouts_LOCAL_PLAYER_UID.json").Hash -eq $plan.real_save_sha256}
    $checks|ConvertTo-Json|Set-Content "$root\restoration-checks.json"
    if(@($checks|Where-Object {-not $_.matches}).Count){throw 'Restoration verification failed; remaining queue stopped'}
}
try{
    SaveStatus
    if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is already running; queue will not interfere'}
    $i=0
    foreach($map in $plan.maps){
        $i++;$current=[string]$map;$state='preparing';SaveStatus
        if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game appeared; stopping queue'}
        $root=Join-Path $batch ('{0:D2}-{1}' -f $i,$map)
        New-Item -ItemType Directory -Path "$root\backup\test-saves" -Force|Out-Null
        Copy-Item "$profile\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg" "$root\backup\autoexec_ns_server.cfg"
        Copy-Item "$profile\mods\BT7274.BotCycleTest\mod.json" "$root\backup\cycle-mod.json"
        Copy-Item "$profile\mods\BT7274.LocalPersistence\mod\scripts\vscripts\bt7274_local_persistence.nut" "$root\backup\persistence-server.nut"
        Copy-Item "$profile\mods\BT7274.MapSurvey\mod\scripts\vscripts\bt7274_map_survey.nut" "$root\backup\survey-harness.nut"
        Get-ChildItem "$profile\save_data\BT7274.LocalPersistence" -Filter '*.json'|ForEach-Object {Copy-Item $_.FullName "$root\backup\test-saves"}
        Copy-Item "$template\survey-mod.json" "$root\survey-mod.json"
        Copy-Item "$template\survey-persistence-readonly.nut" "$root\survey-persistence-readonly.nut"
        Copy-Item "$template\watcher-template.ps1" "$root\watcher-template.ps1"
        $runPlan=[ordered]@{maps=@(@{id=$map});goal=200;time_limit_minutes=15;bots=16;observer=1;build='combat-decisions-v16';dll_sha256=$plan.dll_sha256;aim_error=0.78;real_save_sha256=$plan.real_save_sha256;kind='fresh-process batch member'}
        $runPlan|ConvertTo-Json -Depth 5|Set-Content "$root\plan.json"
        $harness=Get-Content -Raw "$root\backup\survey-harness.nut"
        if([regex]::Matches($harness,'array<string> maps = \[[^\r\n]+\]').Count-ne1){throw 'Unexpected map harness'}
        $harness=[regex]::Replace($harness,'array<string> maps = \[[^\r\n]+\]',('array<string> maps = ["'+$map+'"]'))
        [IO.File]::WriteAllText("$root\survey-one-map.nut",$harness,[Text.UTF8Encoding]::new($false))
        $starter=(Get-Content -Raw "$template\Start-EdenControl.ps1").Replace("'mp_eden'",("'"+$map+"'"))
        $stage='Copy-Item -LiteralPath "$root\survey-one-map.nut" -Destination "$profile\mods\BT7274.MapSurvey\mod\scripts\vscripts\bt7274_map_survey.nut" -Force'
        $starter=$starter.Replace('$cfg=Join-Path $profile',($stage+"`r`n"+'$cfg=Join-Path $profile'))
        [IO.File]::WriteAllText("$root\Start-Match.ps1",$starter,[Text.UTF8Encoding]::new($false))
        $tokens=$null;$parseErrors=$null
        [void][Management.Automation.Language.Parser]::ParseFile("$root\Start-Match.ps1",[ref]$tokens,[ref]$parseErrors)
        if($parseErrors.Count){throw 'Generated starter parse failed'}
        try{
            & "$root\Start-Match.ps1" -RootDirectory $root|Out-File "$root\launch.log"
            $ids=Get-Content -Raw "$root\main\processes.json"|ConvertFrom-Json
            $state='running';SaveStatus
            $deadline=(Get-Date).AddMinutes(25)
            while(Get-Process -Id $ids.watcher_pid -ErrorAction SilentlyContinue){
                if((Get-Date)-gt$deadline){throw 'Per-match watchdog exceeded 25 minutes'}
                Start-Sleep -Seconds 10
                SaveStatus
            }
        }finally{
            # Only stop this runner's exact game, never Steam, EA, or a separate profile.
            if(Test-Path "$root\main\processes.json"){
                $ids=Get-Content -Raw "$root\main\processes.json"|ConvertFrom-Json
                $owned=Get-CimInstance Win32_Process -Filter "ProcessId=$($ids.game_pid)" -ErrorAction SilentlyContinue
                if($owned -and $owned.Name-eq'NorthstarLauncher.exe' -and $owned.CommandLine-like'*map-cycle-test-profile*'){
                    Stop-Process -Id $ids.game_pid -Force
                    Get-Process -Id $ids.game_pid -ErrorAction SilentlyContinue|Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
                }
            }
            if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'A game is still present; refusing to edit loaded profile files'}
            RestoreFiles $root
            CheckRestored $root
        }
        $progress=Get-Content -Raw "$root\main\progress.json"|ConvertFrom-Json
        if($progress.state -notin @('complete','complete_with_report_errors','stopped_error')){
            $progress.state='stopped_error';$progress.failure='Watcher exited without a terminal status'
        }
        # Error-stopped matches need a partial report too; no result is fabricated.
        if($progress.state-eq'stopped_error'){
            $mapLog=Join-Path "$root\main\maps" ("01-$map.log")
            if(Test-Path $mapLog){
                try{
                    $out=Join-Path "$root\main\reports" ("01-$map")
                    & "$audit\Notes\tools\Export-BotSession.ps1" -LogPath $mapLog -OutputDirectory "$out\movement"|Out-Null
                    & "$audit\Notes\tools\Export-CombatDecisions.ps1" -LogPath $mapLog -OutputDirectory "$out\combat"|Out-Null
                    & "$audit\Notes\tools\Review-CombatSession.ps1" -Session "$out\movement" -Combat "$out\combat\combat.csv"|Out-Null
                }catch{[string]$_|Set-Content "$root\partial-analysis-error.txt"}
            }
            @('# Test stopped early','',[string]$progress.failure,'','Last recorded heartbeat (not a final result):',($progress.current|ConvertTo-Json),'','Logs and any partial reports are preserved. Profile restoration was hash-verified.')|Set-Content "$root\main\Summary.md"
        }
        $result=@($progress.results)|Select-Object -Last 1
        $score=if($result){"$($result.imc)-$($result.militia)"}else{"last $($progress.current.imc)-$($progress.current.militia)"}
        $elapsed=if($result){$result.elapsed}else{$progress.current.elapsed}
        $stall=$null;$quick=$null;$areas=@()
        $reviewPath=Join-Path "$root\main\reports" ("01-$map\movement\fine-tune-review.json")
        if(Test-Path $reviewPath){
            $review=Get-Content -Raw $reviewPath|ConvertFrom-Json
            $stall=(@($review.rounds)|Select-Object -First 1).stall_percent
            $churn=@($review.target_churn)|Select-Object -First 1
            if($churn.switches){$quick=[Math]::Round(100*$churn.reversals_within_half_second/$churn.switches,1)}
            $areas=@($review.stall_clusters|Select-Object -First 3)
        }
        $records.Add([pscustomobject]@{map=$map;state=$progress.state;ending=if($result){$result.reason}else{'error'};score=$score;elapsed=$elapsed;stall_percent=$stall;quick_reversal_percent=$quick;top_stall_areas=$areas;failure=$progress.failure;directory=$root})
        $state='between_matches';SaveStatus
    }
    $state=if(@($records|Where-Object {$_.state -ne 'complete'}).Count){'finished_with_issues'}else{'complete'}
    $current=$null
}catch{$failure=[string]$_;$state='stopped_error'}finally{SaveStatus}
