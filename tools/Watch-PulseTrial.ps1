param([string]$Profile,[string]$RunDirectory,[int]$GameProcessId,[string]$Started,[switch]$WithoutPowerCell)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
. "$PSScriptRoot/Northstar-ModState.ps1"
$game=Get-Process -Id $GameProcessId -ErrorAction Stop;$start=[datetime]$Started;$reader=$null;$log=$null
$state=[ordered]@{state='starting';passed=@();failure=$null;power_cell=(!$WithoutPowerCell);without_power_cell_tested=[bool]$WithoutPowerCell}
function Save-State{$state.updated=(Get-Date).ToString('o');$state|ConvertTo-Json|Set-Content "$RunDirectory/progress.json"}
try{
 while((Get-Date)-$start-lt[TimeSpan]::FromMinutes(8)){
  if(!$log){$log=Get-ChildItem "$Profile/logs/nslog*.txt"|Where-Object{$_.CreationTime-ge$start.AddSeconds(-2)}|Sort-Object CreationTime -Descending|Select-Object -First 1;if($log){$reader=[IO.StreamReader]::new([IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite))}}
  if($reader){while($null-ne($line=$reader.ReadLine())){
   if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|PULSE_TRIAL: FAIL'){throw "Pulse validation failed: $line"}
   if($line-match'PULSE_TRIAL: PASS (\S+)'){$state.passed+=@($Matches[1]);$state.state='running'}
   if($line-match'PULSE_TRIAL: COMPLETE bots_unchanged=(\d+)'){$state.bots_unchanged=[int]$Matches[1];$state.state='passed';break}
  }}
  if($state.state-eq'passed'){break};$game.Refresh();if($game.HasExited){throw 'Game exited before validation'};Save-State;Start-Sleep -Seconds 1
 }
 if($state.state-ne'passed'-or$state.passed.Count-ne7-or$state.bots_unchanged-ne15){throw 'Incomplete tactical validation'}
}catch{$state.state='failed';$state.failure=[string]$_}
finally{
 if($reader){$reader.Dispose()};try{Stop-OwnedSurveyGame -Process $game -Profile $Profile}catch{$state.state='failed';$state.failure+='; cleanup: '+[string]$_}
 if($log){Copy-Item $log.FullName "$RunDirectory/raw-session.log"}
 if(!(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
  Copy-Item "$RunDirectory/server.cfg" "$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg" -Force
  Copy-Item "$RunDirectory/BT7274.TacticalRecharge/*" "$Profile/mods/BT7274.TacticalRecharge" -Recurse -Force
  $mods=Get-Content "$RunDirectory/enabledmods.json" -Raw|ConvertFrom-Json;Disable-NorthstarMod $mods 'BT7274.PulseTrial' $Profile;$mods|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json";$state.profile_restored=$true
 };Save-State
}
