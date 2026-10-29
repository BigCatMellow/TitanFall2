param([Parameter(Mandatory)][int]$GameProcessId,[Parameter(Mandatory)][string]$Profile,
    [Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$Started,[switch]$NavigationTrial,[switch]$RouteProbe,[switch]$QueryOnly)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Stop-OwnedSurveyGame.ps1"
. "$PSScriptRoot/Northstar-ModState.ps1"
$game=Get-Process -Id $GameProcessId -ErrorAction Stop
$start=[datetime]$Started
$state=[ordered]@{state='starting';started=$start.ToString('o');completed=@();failure=$null}
$reader=$null;$log=$null
function Save-State {$state.updated=(Get-Date).ToString('o');$state|ConvertTo-Json -Depth 6|Set-Content "$RunDirectory/progress.json"}
try{
    while((Get-Date)-$start-lt[TimeSpan]::FromMinutes(14)){
        if(-not$log){$log=Get-ChildItem "$Profile/logs/nslog*.txt"|Where-Object {$_.CreationTime-ge$start.AddSeconds(-2)}|Sort-Object CreationTime -Descending|Select-Object -First 1
            if($log){$reader=[IO.StreamReader]::new([IO.File]::Open($log.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite))}}
        if($reader){while($null-ne($line=$reader.ReadLine())){
            if($line.Contains('Failed performing northstar origin auth: error Couldn''t connect to server')){continue}
            if($line-match'SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_ROSTER_ERROR|BOT_OBSERVE_ERROR|BOT_MEASURE_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR|SAFETY_TEST_FAILED'){throw "Runtime check failed: $line"}
            if($line-match'SAFETY_TEST_PHASE_PASS name=(\S+)'){$state.completed+=($Matches[1]);$state.state='running'}
            if($line-match'SAFETY_TEST_PHASE .*name=(\S+)'){$state.phase=$Matches[1];$state.state='running'}
            if($line.Contains('SAFETY_TEST_LOBBY')){$state.lobby=$true}
            if($line.Contains('ROUTE_PROBE_DONE')){$state.route_probe_done=$true;if($QueryOnly){$state.state='passed';break}}
            if($line-match'NorthstarLauncher version:\s+(\S+)'){$state.core=$Matches[1]}
            if($line.Contains('SAFETY_TEST_DONE')){$state.state='passed';break}
        }}
        if($state.state-eq'passed'){break}
        $game.Refresh();if($game.HasExited){throw 'Owned game exited before checks completed'}
        Save-State;Start-Sleep -Seconds 1
    }
    $expected=if($NavigationTrial){'nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'}else{'v20_control,v21_safety,hurt_ability_probe,switch_off,new_map_safety'}
    if($QueryOnly){
        if($state.state-ne'passed'-or$state.core-ne'1.31.14.0'-or-not$state.route_probe_done){throw 'Incomplete query-only probe'}
    }elseif($state.state-ne'passed'-or-not$state.lobby-or$state.core-ne'1.31.14.0'-or($state.completed-join',')-ne$expected){throw 'Incomplete safety/map/lobby checks'}
    if($RouteProbe-and-not$state.route_probe_done){throw 'Route probes did not finish'}
}catch{$state.state='failed';$state.failure=[string]$_}
finally{
    if($reader){$reader.Dispose()}
    try{Stop-OwnedSurveyGame -Process $game -Profile $Profile}catch{$state.state='failed';$state.failure+='; shutdown: '+[string]$_}
    if($log){Copy-Item -LiteralPath $log.FullName -Destination "$RunDirectory/raw-session.log"}
    if(Test-Path "$RunDirectory/idle.cfg"){Copy-Item "$RunDirectory/idle.cfg" "$Profile/mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg" -Force}
    $enabled=Get-Content "$RunDirectory/enabledmods-before.json" -Raw|ConvertFrom-Json
    foreach($name in @('BT7274.DecisionTest','BT7274.WeaponIntegrationTest','BT7274.CapabilityTest','BT7274.SafetyTest','BT7274.RouteProbe','BT7274.BotMeasurements')){Disable-NorthstarMod $enabled $name $Profile}
    $bridgeVersion=(Get-Content "$Profile/mods/BT7274.BotDecisions/mod.json" -Raw|ConvertFrom-Json).Version
    Disable-NorthstarMod $enabled 'BT7274.BotDecisions' $Profile
    $enabled.'BT7274.BotDecisions'|Add-Member -NotePropertyName $bridgeVersion -NotePropertyValue $true -Force
    $enabled|ConvertTo-Json -Depth 10|Set-Content "$Profile/enabledmods.json"
    Save-State
}
