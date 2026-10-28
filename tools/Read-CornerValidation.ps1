function Test-CornerValidationEvidence($Progress,$Session,$Context,[string]$NativeHash,[string]$BridgeHash,[string]$CoreHash) {
    $expected='nav_control,nav_guard,nav_respawn,nav_disabled,nav_new_map'
    if($Progress.state-ne'passed'-or-not$Progress.lobby-or$Progress.core-ne'1.31.14.0'-or($Progress.completed-join',')-ne$expected){throw 'Require complete navigation control/guard/respawn/disable/lobby/new-map smoke'}
    if($Context.experiment-ne'navigation_v22'-or$Context.population-ne'16bots_inactive_human'){throw 'Wrong experiment or population evidence'}
    if($Session.native_sha256-ne$NativeHash-or$Session.bridge_sha256-ne$BridgeHash-or$Context.core_sha256-ne$CoreHash){throw 'Navigation smoke runtime hash mismatch'}
    foreach($hash in @($NativeHash,$BridgeHash,$CoreHash)){if($hash-notmatch'^[a-fA-F0-9]{64}$'){throw 'Invalid runtime hash'}}
}
function Read-CornerValidation([string]$Directory,[string]$Profile) {
    $p=Get-Content "$Directory/progress.json" -Raw|ConvertFrom-Json
    $s=Get-Content "$Directory/session.json" -Raw|ConvertFrom-Json
    $c=Get-Content "$Directory/context.json" -Raw|ConvertFrom-Json
    if((Split-Path ([IO.Path]::GetFullPath($Profile)) -Leaf)-ne'map-cycle-test-profile'){throw 'Corner surveys require the working isolated profile'}
    if((Get-Item "$Profile/Northstar.dll").VersionInfo.FileVersion-ne'1.31.14'){throw 'Wrong core version'}
    $native=(Get-FileHash "$Profile/plugins/bp_ort.dll").Hash
    $bridge=(Get-FileHash "$Profile/mods/BT7274.BotDecisions/mod/scripts/vscripts/bt7274_bot_decisions.nut").Hash
    $core=(Get-FileHash "$Profile/Northstar.dll").Hash
    Test-CornerValidationEvidence $p $s $c $native $bridge $core
    $states=@(Select-String -LiteralPath "$Directory/raw-session.log" -Pattern 'SAFETY_TEST_NAV_STATE phase=(\S+) corner=(true|false)'|ForEach-Object {$_.Matches[0].Groups[1].Value+'='+$_.Matches[0].Groups[2].Value})
    if(($states-join',')-ne'nav_control=false,nav_guard=true,nav_respawn=true,nav_disabled=false,nav_new_map=true'){throw 'Navigation smoke lacks actual switch readback'}
    [pscustomobject]@{dll_sha256=$native;bridge_sha256=$bridge;core_sha256=$core}
}
