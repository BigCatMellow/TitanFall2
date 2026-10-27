$ErrorActionPreference='Stop'
. "$PSScriptRoot/../tools/Solo-TrialSettings.ps1"
function Require([bool]$ok,[string]$message){if(-not$ok){throw $message};"PASS: $message"}
$movement=Get-SoloTrialSettings Movement
Require ($movement.bot_combat_movement-eq1-and$movement.bot_proximity_fix-eq1-and$movement.bt7274_bot_roster-eq0) 'Default trial enables movement/proximity without the roster'
foreach($preset in @('Baseline','Movement','Height','Roster','Skills','Full')){
    $s=Get-SoloTrialSettings $preset
    Require (-not($s.Keys|Where-Object {$_-match'aim|damage|warmup|recharge|reload'})) "$preset preserves aim, damage, timing and human modifiers"
    Require ($s.bot_crouch_recovery-eq0-and$s.bot_perception_fix-eq0-and$s.bot_jump_timing-eq0-and$s.bot_route_guard-eq0) "$preset leaves gated geometry/perception trials off"
}
# File-write fixture runs only while no real game is active, like deployment.
if(-not(Get-Process NorthstarLauncher,Titanfall2 -ErrorAction SilentlyContinue)){
    $root=Join-Path ([IO.Path]::GetTempPath()) ('bt7274-trial-'+[guid]::NewGuid().ToString('N'))
    try{
        $profile=Join-Path $root 'profile';$folder=Join-Path $profile 'mods/Northstar.CustomServers/mod/cfg'
        New-Item -ItemType Directory $folder -Force|Out-Null
        $cfg=Join-Path $folder 'autoexec_ns_server.cfg'
        "bot_aim_error_scale 0.78`nbt7274_tactical_recharge 1`nbot_combat_movement 0`n"|Set-Content $cfg
        Write-SoloTrialSettings $profile Full (Get-SoloTrialSettings Full)
        $text=Get-Content $cfg -Raw
        Require ($text-match'bot_aim_error_scale 0.78'-and$text-match'bt7274_tactical_recharge 1'-and$text-match'bot_personality 1') 'Preset write preserves existing play settings'
        $hash=(Get-FileHash $cfg).Hash
        Write-SoloTrialSettings $profile Full (Get-SoloTrialSettings Full)
        Require ((Get-FileHash $cfg).Hash-eq$hash) 'Repeated preset selection is idempotent'
        [IO.File]::WriteAllText($cfg,'')
        Write-SoloTrialSettings $profile Baseline (Get-SoloTrialSettings Baseline)
        Require ((Get-Content $cfg -Raw)-match'bot_combat_movement 0') 'Empty config is handled without a trim loop'
    }finally{
        if((Split-Path ([IO.Path]::GetFullPath($root)) -Parent)-eq([IO.Path]::GetTempPath().TrimEnd('\','/'))){Remove-Item -LiteralPath $root -Recurse -Force}
    }
}
