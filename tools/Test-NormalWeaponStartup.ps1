param([string]$Profile="$env:USERPROFILE\northstar-crash-audit\local-test-profile",
    [string]$GameDirectory='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2',
    [Parameter(Mandatory)][string]$RunDirectory)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Another game is already running'}
if(Test-Path $RunDirectory){throw 'Preserve the previous startup check'}
New-Item -ItemType Directory -Path $RunDirectory|Out-Null
$started=Get-Date;$process=$null;$reader=$null
$saves=@(Get-ChildItem "$Profile/save_data" -Recurse -File|ForEach-Object {@{path=$_.FullName;hash=(Get-FileHash -LiteralPath $_.FullName).Hash}})
$state=[ordered]@{state='starting';started=$started.ToString('o');profile=$Profile;core=$null;build=$null;restored_fields=0;bots=0;humans=0;failure=$null}
function Save-StartupState {$state.updated=(Get-Date).ToString('o');$state|ConvertTo-Json -Depth 5|Set-Content "$RunDirectory/status.json"}
try{
    $process=Start-Process -FilePath "$GameDirectory/NorthstarLauncher.exe" -WorkingDirectory $GameDirectory -WindowStyle Normal -PassThru -ArgumentList "-profile=$Profile",'-novid','-fullscreen','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16"','+mp_gamemode','tdm','+map','mp_eden'
    $state.game_pid=$process.Id;Save-StartupState
    $log=$null;$healthy=$null;$frameBots=0;$frameHumans=0
    while((Get-Date)-$started-lt[TimeSpan]::FromMinutes(4)){
        if(-not$log){
            $log=Get-ChildItem "$Profile/logs" -Filter 'nslog*.txt'|Where-Object {$_.CreationTime -ge $started.AddSeconds(-2)}|Sort-Object CreationTime -Descending|Select-Object -First 1
            if($log){$reader=[IO.StreamReader]::new([IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite));$state.log=$log.FullName}
        }
        if($reader){while($null-ne($line=$reader.ReadLine())){
            if($line.Contains('Failed performing northstar origin auth: error Couldn''t connect to server')){continue}
            if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|\[error\]'){throw "Normal startup error: $line"}
            if($line-match'NorthstarLauncher version:\s+(\S+)'){$state.core=$Matches[1];if($state.core-ne'1.31.14.0'){throw 'Unexpected normal runtime'}}
            if($line.Contains('local build:')){$state.build=$line.Substring($line.IndexOf('local build:'))}
            if($line-match'LOCAL_LOADOUTS: restored (\d+) named fields'){$state.restored_fields=[int]$Matches[1]}
            if($line.Contains('BOT_FRAME ')){$frameBots=0;$frameHumans=0}
            if($line.Contains('BOT_PLAYER ')){
                if($line-match'\bbot=1\b'){$frameBots++}elseif($line-match'\bbot=0\b'){$frameHumans++}
                $state.bots=[Math]::Max($state.bots,$frameBots);$state.humans=[Math]::Max($state.humans,$frameHumans)
            }
        }}
        if($state.bots-eq15-and$state.humans-eq1-and$state.restored_fields-gt0-and$state.build-like'*weapons-v19*'){
            if(-not$healthy){$healthy=Get-Date}
            if((Get-Date)-$healthy-ge[TimeSpan]::FromSeconds(12)){$state.state='passed';break}
        }
        $process.Refresh();if($process.HasExited){throw 'Normal game exited before startup checks passed'}
        Save-StartupState;Start-Sleep -Seconds 1
    }
    if($state.state-ne'passed'){throw 'Normal startup did not establish restored loadouts and human+15 bots'}
}catch{$state.state='failed';$state.failure=[string]$_}
finally{
    if($reader){$reader.Dispose()}
    try{Stop-OwnedSurveyGame -Process $process -Profile $Profile}catch{$state.state='failed';$state.failure+='; shutdown: '+[string]$_}
    if($log){Copy-Item -LiteralPath $log.FullName -Destination "$RunDirectory/raw-session.log" -Force}
    $state.save_files_unchanged=@($saves|Where-Object {(Get-FileHash -LiteralPath $_.path).Hash-eq$_.hash}).Count
    $state.save_files=$saves.Count
    Save-StartupState
}
