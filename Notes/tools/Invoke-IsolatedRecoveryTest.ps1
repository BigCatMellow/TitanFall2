param([ValidateSet(0,1)][int]$Enabled=1)
$ErrorActionPreference='Stop'
$profile='C:\Users\james\northstar-crash-audit\map-cycle-test-profile'
$game='C:\Program Files (x86)\Steam\steamapps\common\Titanfall2'
$dll='C:\Users\james\bp-ort-fork\target\x86_64-pc-windows-gnu\distribution\bp_ort.dll'
$old=Get-CimInstance Win32_Process -Filter "Name='NorthstarLauncher.exe'" |
    Where-Object {$_.CommandLine -like "*-profile=$profile*"}
foreach($g in $old){$p=Get-Process -Id $g.ProcessId; Stop-Process -Id $p.Id -Force; if(-not $p.WaitForExit(10000)){throw 'Isolated game failed to exit'}}
Copy-Item -LiteralPath $dll -Destination "$profile\plugins\bp_ort.dll" -Force
$cfg="$profile\mods\Northstar.CustomServers\mod\cfg\autoexec_ns_server.cfg"
$content=(Get-Content -LiteralPath $cfg -Raw) -replace '(?m)^bot_(route|escape)_recovery .*\r?\n?',''
Set-Content -LiteralPath $cfg -Value ($content+"`r`nbot_escape_recovery $Enabled`r`n")
$before=@(Get-ChildItem -LiteralPath "$profile\logs" -Filter 'nslog*.txt'|ForEach-Object Name)
$launch=Start-Process -FilePath "$game\NorthstarLauncher.exe" -WorkingDirectory $game -ArgumentList "-profile=$profile",'-novid','-ip','127.0.0.1','-port','37025','-maxplayersplaylist','+setplaylist','tdm','+setplaylistvaroverrides','"max_players 16"','+mp_gamemode','tdm','+map','mp_eden' -WindowStyle Normal -PassThru
"Isolated PID $($launch.Id); recovery $Enabled; DLL $((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash)"
$deadline=(Get-Date).AddMinutes(6); $log=$null
while((Get-Date) -lt $deadline){
    if(-not $log){$log=Get-ChildItem -LiteralPath "$profile\logs" -Filter 'nslog*.txt'|Where-Object {$_.Name -notin $before}|Sort-Object LastWriteTime -Descending|Select-Object -First 1}
    if($log -and (Select-String -LiteralPath $log.FullName -SimpleMatch 'BOT_CYCLE_TEST: finished two map changes' -Quiet)){break}
    if($launch.HasExited){throw "Isolated game exited early. Log: $($log.FullName)"}
    Start-Sleep -Seconds 1
}
if(-not $log -or -not(Select-String -LiteralPath $log.FullName -SimpleMatch 'BOT_CYCLE_TEST: finished two map changes' -Quiet)){throw 'Isolated map-cycle test timed out; inspect before continuing'}
Stop-Process -Id $launch.Id -Force
if(-not $launch.WaitForExit(10000)){throw 'Isolated game failed to exit after test'}
"Completed log: $($log.FullName)"
& "$PSScriptRoot\Export-BotSession.ps1" -LogPath $log.FullName
