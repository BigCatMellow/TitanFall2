function Get-SoloTrialSettings([ValidateSet('Baseline','Movement','Height','Roster','Skills','Full')][string]$Trial) {
    $settings=[ordered]@{
        bot_nav_diagnostics=1;bot_route_guard=0;bot_jump_timing=0;bot_proximity_fix=0;
        bot_perception_fix=0;bot_combat_movement=0;bot_crouch_recovery=0;
        bot_height_response=0;bot_defensive_tactics=0;bot_skill_use=0;bot_personality=0;
        bt7274_bot_roster=0;bt7274_bot_tacticals=0;solo_weapon_notes_fire=1;solo_weapon_notes_viewkick=0
    }
    if($Trial-ne'Baseline'){$settings.bot_combat_movement=1;$settings.bot_proximity_fix=1}
    if($Trial-in@('Height','Roster','Skills','Full')){$settings.bot_height_response=1}
    if($Trial-in@('Roster','Skills','Full')){$settings.bt7274_bot_roster=1}
    if($Trial-in@('Skills','Full')){$settings.bt7274_bot_tacticals=1;$settings.bot_skill_use=1;$settings.bot_defensive_tactics=1}
    if($Trial-eq'Full'){$settings.bot_personality=1}
    return $settings
}
function Write-SoloTrialSettings([string]$Profile,[string]$Trial,$Settings) {
    # Server autoexec can override +convars from the command line. Persist only
    # the selected trial's explicit switches while the game is closed.
    if(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue){throw 'Close the game before changing a trial'}
    $cfg=Join-Path $Profile 'mods/Northstar.CustomServers/mod/cfg/autoexec_ns_server.cfg'
    $original=[IO.File]::ReadAllText($cfg)
    $pattern='^\s*(?:'+(($Settings.Keys|ForEach-Object {[regex]::Escape($_)})-join'|')+')\s+'
    $retained=@($original -split '\r?\n'|Where-Object {$_-notmatch$pattern})
    while($retained.Count-and$retained[-1]-eq''){
        if($retained.Count-eq1){$retained=@();break}
        $retained=$retained[0..($retained.Count-2)]
    }
    $canonical=@($Settings.GetEnumerator()|ForEach-Object {$_.Key+' '+$_.Value})
    $updated=($retained+$canonical)-join[Environment]::NewLine
    $updated+=[Environment]::NewLine
    if($updated-ne$original){
        $backups=Join-Path (Split-Path $Profile) 'Notes/trial-config-backups'
        New-Item -ItemType Directory $backups -Force|Out-Null
        $backup=Join-Path $backups ((Get-Date -Format yyyyMMdd-HHmmss)+'-'+[guid]::NewGuid().ToString('N')+'.cfg')
        $temp=$cfg+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
        [IO.File]::WriteAllText($temp,$updated)
        [IO.File]::Replace($temp,$cfg,$backup)
    }
    @{trial=$Trial;settings=$Settings;updated=(Get-Date).ToString('o')}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $Profile 'bt7274-current-trial.json')
}
