param([Parameter(Mandatory=$true)][int]$GameProcessId,[Parameter(Mandatory=$true)][string]$RunDirectory,[Parameter(Mandatory=$true)][string]$RootDirectory,[switch]$Smoke)
$ErrorActionPreference='Stop'
$audit='C:\Users\james\northstar-crash-audit'; $profile=Join-Path $audit 'map-cycle-test-profile'
$allowed=Join-Path $audit 'Notes\map-surveys'
$root=[IO.Path]::GetFullPath($RootDirectory)
$run=[IO.Path]::GetFullPath($RunDirectory)
if(-not $root.StartsWith($allowed+'\',[StringComparison]::OrdinalIgnoreCase) -or -not $run.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected run directory'}
New-Item -ItemType Directory -Path "$run\maps" -Force | Out-Null
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class SurveyAwake { [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags); }'
[void][SurveyAwake]::SetThreadExecutionState([uint32]2147483649)
$began=Get-Date; $lastSurvey=Get-Date; $logPath=$null; $reader=$null; $writer=$null; $buildLine=''; $done=$false; $state='starting'; $failure=$null; $current=$null; $mapBegan=$began
$results=[Collections.Generic.List[object]]::new(); $analysisErrors=[Collections.Generic.List[string]]::new()
function Fields([string]$line){$b=@{};foreach($m in [regex]::Matches($line,'(?:^|\s)([a-z_]+)=([^\s]+)')){$b[$m.Groups[1].Value]=$m.Groups[2].Value};return $b}
function OwnedGame {
    $p=Get-CimInstance Win32_Process -Filter "ProcessId=$GameProcessId" -ErrorAction SilentlyContinue
    return $p -and $p.Name-eq'NorthstarLauncher.exe' -and $p.CommandLine -like "*map-cycle-test-profile*"
}
function StopOwnedGame {
    if(OwnedGame){Stop-Process -Id $GameProcessId -Force -ErrorAction SilentlyContinue;Get-Process -Id $GameProcessId -ErrorAction SilentlyContinue | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue}
}
function Progress {
    $data=[ordered]@{state=$state;updated=(Get-Date).ToString('o');smoke=[bool]$Smoke;pid=$GameProcessId;log=$logPath;current=$current;completed=$results.Count;expected=1;results=$results.ToArray();failure=$failure;analysis_errors=$analysisErrors.ToArray()}
    $json=$data|ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText("$run\progress.tmp",$json,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath "$run\progress.tmp" -Destination "$run\progress.json" -Force
    $lines=@("State: $state","Updated: $((Get-Date).ToString('HH:mm:ss'))","Completed maps: $($results.Count) / 1", "Current: $($current|ConvertTo-Json -Compress)","Failure: $failure",'', 'Completed results:')
    $lines+=@($results|ForEach-Object{"$($_.map): $($_.imc)-$($_.militia), $($_.reason), $($_.elapsed)s"})
    [IO.File]::WriteAllLines("$run\Progress.txt",$lines,[Text.UTF8Encoding]::new($false))
}
try {
    Progress
    while(-not $logPath -and (Get-Date)-$began -lt [TimeSpan]::FromMinutes(4)){
        $candidate=Get-ChildItem "$profile\logs" -Filter 'nslog*.txt' | Where-Object{$_.CreationTime-ge$began.AddSeconds(-10)} | Sort-Object CreationTime -Descending | Select-Object -First 1
        if($candidate){$logPath=$candidate.FullName;break}
        if(-not(OwnedGame)){throw 'Game exited before a new log appeared'}
        Start-Sleep -Seconds 2
    }
    if(-not $logPath){throw 'No new game log appeared'}
    $stream=[IO.File]::Open($logPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader=[IO.StreamReader]::new($stream)
    $state='warming_up';Progress
    while($true){
        while($null-ne($line=$reader.ReadLine())){
            if($line.Contains('local build:')){$buildLine=$line}
            if($writer){$writer.WriteLine($line)}
            if($line -match 'SCRIPT ERROR|COMPILE ERROR|Access violation|panicked|\[error\]'){throw "Game error: $line"}
            if($line.Contains('MAP_SURVEY_')){$lastSurvey=Get-Date}
            if($line.Contains('MAP_SURVEY_BEGIN ')){
                if($writer){$writer.Dispose()}
                $f=Fields $line; $current=$f; $state='running'; $mapBegan=Get-Date
                $mapLog=Join-Path "$run\maps" ('{0:D2}-{1}.log' -f ([int]$f.index+1),$f.map)
                $writer=[IO.StreamWriter]::new($mapLog,$false,[Text.UTF8Encoding]::new($false));$writer.AutoFlush=$true
                $writer.WriteLine($buildLine);$writer.WriteLine($line);Progress
            }
            elseif($line.Contains('MAP_SURVEY_SCORE ')){$current=Fields $line;Progress}
            elseif($line.Contains('MAP_SURVEY_RESULT ')){
                $f=Fields $line
                $f['log_file']=Join-Path "$run\maps" ('{0:D2}-{1}.log' -f ([int]$f.index+1),$f.map)
                $results.Add([pscustomobject]$f)
                if($writer){$writer.Dispose();$writer=$null}
                $state='changing_map';Progress
                if($f.valid-ne'true'){throw "Invalid map sample: $($f.reason)"}
            }
            elseif($line.Contains('MAP_SURVEY_DONE ')){$done=$true;$state='finishing';Progress}
        }
        if($done){Start-Sleep -Seconds 8;StopOwnedGame;break}
        if(-not(OwnedGame)){
            Start-Sleep -Seconds 1
            if($reader.EndOfStream){throw 'Game closed before the survey completed'}
        }
        if((Get-Date)-$lastSurvey -gt [TimeSpan]::FromMinutes(4)){throw 'No survey heartbeat for four minutes'}
        if($state-eq'running' -and (Get-Date)-$mapBegan-gt[TimeSpan]::FromMinutes(19)){throw 'A map exceeded the wall-clock watchdog limit'}
        if((Get-Date)-$began -gt [TimeSpan]::FromMinutes(145)){throw 'Whole-run wall-clock limit reached'}
        Start-Sleep -Seconds 2
    }
    if($writer){$writer.Dispose();$writer=$null};$reader.Dispose();$reader=$null
    Copy-Item -LiteralPath $logPath -Destination "$run\raw-session.log" -Force
    foreach($r in $results){
        $saved=Join-Path "$profile\save_data\James.MapSurvey" ("result_$($r.index)_$($r.map).json")
        if(Test-Path $saved){Copy-Item -LiteralPath $saved -Destination "$run\maps" -Force}
    }
    if(-not $Smoke){
        $state='analyzing';Progress
        foreach($r in $results){
            $out=Join-Path "$run\reports" ('{0:D2}-{1}' -f ([int]$r.index+1),$r.map)
            try{
                & "$audit\Notes\tools\Export-BotSession.ps1" -LogPath $r.log_file -OutputDirectory "$out\movement" | Out-Null
                & "$audit\Notes\tools\Export-CombatDecisions.ps1" -LogPath $r.log_file -OutputDirectory "$out\combat" | Out-Null
                & "$audit\Notes\tools\Review-CombatSession.ps1" -Session "$out\movement" -Combat "$out\combat\combat.csv" | Out-Null
            }catch{$analysisErrors.Add("$($r.map): $_")}
            Progress
        }
    }
    $results.ToArray()|Export-Csv "$run\results.csv" -NoTypeInformation
    if(-not $Smoke){ try{ & "$audit\Notes\tools\Summarize-MapSurvey.ps1" -RunDirectory $run }catch{$analysisErrors.Add("Summary: $_")} }
    $state=if($analysisErrors.Count){'complete_with_report_errors'}else{'complete'}
}catch{
    $failure=[string]$_;$state='stopped_error';StopOwnedGame
    if($writer){$writer.Dispose();$writer=$null};if($reader){$reader.Dispose();$reader=$null}
    if($logPath -and (Test-Path $logPath)){Copy-Item -LiteralPath $logPath -Destination "$run\raw-session.log" -Force}
}finally{
    if(-not $Smoke){
        try{
            Copy-Item -LiteralPath "$root\backup\autoexec_ns_server.cfg" -Destination "$profile\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg" -Force
            Copy-Item -LiteralPath "$root\backup\cycle-mod.json" -Destination "$profile\mods\James.BotCycleTest\mod.json" -Force
            if(Test-Path "$root\backup\persistence-server.nut"){ Copy-Item -LiteralPath "$root\backup\persistence-server.nut" -Destination "$profile\mods\James.LocalPersistence\mod\scripts\vscripts\james_local_persistence.nut" -Force }
            foreach($json in Get-ChildItem "$root\backup\test-saves" -Filter '*.json'){ Copy-Item -LiteralPath $json.FullName -Destination "$profile\save_data\James.LocalPersistence" -Force }
            Copy-Item -LiteralPath "$root\backup\survey-harness.nut" -Destination "$profile\mods\James.MapSurvey\mod\scripts\vscripts\james_map_survey.nut" -Force
            $disabled="$profile\mods\James.BotCycleTest\mod.json.map-survey-disabled"
            if(Test-Path $disabled){Remove-Item -LiteralPath $disabled -Force}
            if(Test-Path "$profile\mods\James.MapSurvey\mod.json"){
                Move-Item -LiteralPath "$profile\mods\James.MapSurvey\mod.json" -Destination "$root\survey-mod.json" -Force
            }
        }catch{$analysisErrors.Add("Cleanup: $_")}
    }
    $results.ToArray()|Export-Csv "$run\results.csv" -NoTypeInformation
    Progress
    [void][SurveyAwake]::SetThreadExecutionState([uint32]2147483648)
}
