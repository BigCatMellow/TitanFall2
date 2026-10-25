param([Parameter(Mandatory)][int]$GameProcessId,[Parameter(Mandatory)][string]$Profile,[Parameter(Mandatory)][string]$RunDirectory,[switch]$Dedicated,[switch]$Quick)
$ErrorActionPreference='Stop'
$started=Get-Date
$state=[ordered]@{state='starting';pid=$GameProcessId;started=$started.ToString('o');dedicated=[bool]$Dedicated;quick=[bool]$Quick;phase=$null;completed=@();log=$null;failure=$null}
New-Item -ItemType Directory -Path $RunDirectory -Force|Out-Null
function Save-State {$state.updated=(Get-Date).ToString('o');$state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$RunDirectory/progress.json"}
function Owned-Game {
    $p=Get-CimInstance Win32_Process -Filter "ProcessId=$GameProcessId" -ErrorAction SilentlyContinue
    $p-and$p.Name-eq'NorthstarLauncher.exe'-and$p.CommandLine-and$p.CommandLine.Contains("-profile=$Profile")
}
function Stop-Owned {if(Owned-Game){Stop-Process -Id $GameProcessId -Force;Wait-Process -Id $GameProcessId -Timeout 15 -ErrorAction SilentlyContinue}}
$reader=$null
try{
    Save-State
    $until=(Get-Date).AddMinutes(3)
    while(-not$state.log-and(Get-Date)-lt$until){
        $log=Get-ChildItem -LiteralPath "$Profile/logs" -Filter 'nslog*.txt' -ErrorAction SilentlyContinue|Where-Object CreationTime -ge $started.AddSeconds(-30)|Sort-Object CreationTime -Descending|Select-Object -First 1
        if($log){$state.log=$log.FullName;break}
        if(-not(Owned-Game)){throw 'Test game exited before creating its log'}
        Start-Sleep -Seconds 1
    }
    if(-not$state.log){throw 'No test log within three minutes'}
    $stream=[IO.File]::Open($state.log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    $reader=[IO.StreamReader]::new($stream)
    $lastHeartbeat=Get-Date;$lastSave=Get-Date;$done=$false
    while(-not$done){
        while($null-ne($line=$reader.ReadLine())){
            if($line-match'NorthstarLauncher version:\s+(\S+)'){
                $state.core_version=$Matches[1]
                if($state.core_version-ne'1.31.14.0'){throw 'Wrong Northstar runtime in test process; do not mix core and mod versions'}
            }
            if($line-match'local build:'){$state.build=$line}
            if($line.Contains('Failed performing northstar origin auth: error Couldn''t connect to server')){
                $state.online_auth_warning='Origin authentication service unreachable; local insecure test does not use it'
                continue
            }
            if($line-match'SCRIPT ERROR|COMPILE ERROR|Access violation|FatalError|Host_Error|panicked|\[error\]'){throw "Runtime error: $line"}
            if($line-match'DECISION_TEST_BEGIN .*phase=(\d+)'){
                $state.phase=[int]$Matches[1]
                if($Quick-and$state.phase-notin@(4,6)){throw 'Quick test started an unexpected phase; check startup argument ordering'}
                $state.state='running';$lastHeartbeat=Get-Date;Save-State
            }
            if($line-match'DECISION_TEST_HEARTBEAT'){$lastHeartbeat=Get-Date;$state.heartbeat=$line}
            if($line-match'DECISION_TEST_PHASE_PASS .*phase=(\d+)'){$state.completed+=([int]$Matches[1]);$state.state='transitioning';Save-State}
            if($line.Contains('DECISION_TEST_LOBBY:')){$state.lobby=$true;$lastHeartbeat=Get-Date;Save-State}
            if($line.Contains('DECISION_TEST_DONE:')){$done=$true;break}
        }
        if(-not$done-and-not(Owned-Game)){throw 'Test game exited before completing phases'}
        if((Get-Date)-$lastHeartbeat-gt[TimeSpan]::FromMinutes(4)){throw 'No test heartbeat for four minutes'}
        if((Get-Date)-$started-gt[TimeSpan]::FromMinutes(25)){throw 'Candidate test exceeded 25 minutes'}
        if((Get-Date)-$lastSave-gt[TimeSpan]::FromSeconds(5)){Save-State;$lastSave=Get-Date}
        if(-not$done){Start-Sleep -Seconds 1}
    }
    $expected=if($Quick){'4,6'}else{'0,1,2,3,4,6'}
    if(($state.completed-join',')-ne$expected-or(-not$Dedicated-and-not$state.lobby)){throw 'Incomplete phase/lobby coverage'}
    $state.state='passed'
}catch{$state.state='failed';$state.failure=[string]$_}
finally{
    if($reader){$reader.Dispose()}
    Stop-Owned
    if($state.log){Copy-Item -LiteralPath $state.log -Destination "$RunDirectory/raw-session.log" -Force}
    Save-State
}
