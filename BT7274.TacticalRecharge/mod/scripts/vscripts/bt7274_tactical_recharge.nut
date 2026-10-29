global function BT7274TacticalRecharge_Init
global function BT7274TacticalRecharge_Apply
const string BT7274_TACTICAL_MOD = "bt7274_tactical_recharge"
struct { table pending } file

void function BT7274TacticalRecharge_Init()
{
    AddCallback_OnPlayerRespawned( BT7274TacticalRecharge_Respawn )
    AddCallback_OnPlayerGetsNewPilotLoadout( BT7274TacticalRecharge_Loadout )
}
void function BT7274TacticalRecharge_Respawn( entity player )
{
    BT7274TacticalRecharge_Schedule( player )
}
void function BT7274TacticalRecharge_Loadout( entity player, PilotLoadoutDef loadout )
{
    BT7274TacticalRecharge_Schedule( player )
}
void function BT7274TacticalRecharge_Schedule( entity player )
{
    if ( !IsValid( player ) || player.GetUID() == "0" ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread BT7274TacticalRecharge_AfterLoadout( player )
}
void function BT7274TacticalRecharge_AfterLoadout( entity player )
{
    WaitEndFrame()
    file.pending[ player ] <- false
    if ( IsValid( player ) ) BT7274TacticalRecharge_Apply( player )
}
void function BT7274TacticalRecharge_Apply( entity player )
{
    if ( !IsValid( player ) || !IsAlive( player ) || player.IsTitan() || IsLobby()
        || player.GetUID() == "0" || !NSIsPlayerLocalPlayer( player )
        || !GetConVarBool( "ns_auth_allow_insecure" ) ) return
    // Restrict class modifiers to standard pilots, never spectators/Titans.
    string settings = player.GetPlayerSettings()
    if ( settings.find( "pilot_" ) != 0 ) return
    entity tactical = player.GetOffhandWeapon( OFFHAND_LEFT )
    if ( !IsValid( tactical ) ) return
    bool enabled = GetConVarBool( "bt7274_tactical_recharge" )
    string weaponClass = tactical.GetWeaponClassName()
    array<string> settingMods = player.GetPlayerSettingsMods()
    bool wantGrapple = enabled && weaponClass == "mp_ability_grapple"
    bool hadGrapple = settingMods.contains( BT7274_TACTICAL_MOD )
    if ( wantGrapple != hadGrapple )
    {
        if ( wantGrapple ) settingMods.append( BT7274_TACTICAL_MOD )
        else settingMods.removebyvalue( BT7274_TACTICAL_MOD )
        player.SetPlayerSettingsWithMods( settings, settingMods )
    }
    array<string> supported = ["mp_ability_cloak","mp_ability_heal","mp_ability_holopilot",
        "mp_ability_shifter","mp_weapon_grenade_sonar","mp_weapon_deployable_cover"]
    if ( supported.contains( weaponClass ) )
    {
        array<string> weaponMods = tactical.GetMods()
        bool present = weaponMods.contains( BT7274_TACTICAL_MOD )
        if ( enabled != present )
        {
            if ( enabled ) weaponMods.append( BT7274_TACTICAL_MOD )
            else weaponMods.removebyvalue( BT7274_TACTICAL_MOD )
            tactical.SetMods( weaponMods )
        }
    }
    array<string> accelerated = ["mp_ability_grapple","mp_ability_cloak","mp_ability_heal",
        "mp_ability_holopilot","mp_ability_shifter","mp_weapon_deployable_cover"]
    string profile = enabled && accelerated.contains( weaponClass ) ? "half" : "native"
    print( "TACTICAL_RECHARGE: local weapon=" + weaponClass + " enabled=" + enabled
        + " profile=" + profile + " settings=" + settings )
}
