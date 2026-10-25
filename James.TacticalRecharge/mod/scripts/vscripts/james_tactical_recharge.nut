global function JamesTacticalRecharge_Init
global function JamesTacticalRecharge_Apply
const string JAMES_TACTICAL_MOD = "james_tactical_recharge"
struct { table pending } file

void function JamesTacticalRecharge_Init()
{
    AddCallback_OnPlayerRespawned( JamesTacticalRecharge_Respawn )
    AddCallback_OnPlayerGetsNewPilotLoadout( JamesTacticalRecharge_Loadout )
}
void function JamesTacticalRecharge_Respawn( entity player )
{
    JamesTacticalRecharge_Schedule( player )
}
void function JamesTacticalRecharge_Loadout( entity player, PilotLoadoutDef loadout )
{
    JamesTacticalRecharge_Schedule( player )
}
void function JamesTacticalRecharge_Schedule( entity player )
{
    if ( !IsValid( player ) || player.GetUID() == "0" ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread JamesTacticalRecharge_AfterLoadout( player )
}
void function JamesTacticalRecharge_AfterLoadout( entity player )
{
    WaitEndFrame()
    file.pending[ player ] <- false
    if ( IsValid( player ) ) JamesTacticalRecharge_Apply( player )
}
void function JamesTacticalRecharge_Apply( entity player )
{
    if ( !IsValid( player ) || !IsAlive( player ) || player.IsTitan() || IsLobby()
        || player.GetUID() == "0" || !NSIsPlayerLocalPlayer( player )
        || !GetConVarBool( "ns_auth_allow_insecure" ) ) return
    // Restrict class modifiers to standard pilots, never spectators/Titans.
    string settings = player.GetPlayerSettings()
    if ( settings.find( "pilot_" ) != 0 ) return
    entity tactical = player.GetOffhandWeapon( OFFHAND_LEFT )
    if ( !IsValid( tactical ) ) return
    bool enabled = GetConVarBool( "james_tactical_recharge" )
    string weaponClass = tactical.GetWeaponClassName()
    array<string> settingMods = player.GetPlayerSettingsMods()
    bool wantGrapple = enabled && weaponClass == "mp_ability_grapple"
    bool hadGrapple = settingMods.contains( JAMES_TACTICAL_MOD )
    if ( wantGrapple != hadGrapple )
    {
        if ( wantGrapple ) settingMods.append( JAMES_TACTICAL_MOD )
        else settingMods.removebyvalue( JAMES_TACTICAL_MOD )
        player.SetPlayerSettingsWithMods( settings, settingMods )
    }
    array<string> supported = ["mp_ability_cloak","mp_ability_heal","mp_ability_holopilot",
        "mp_ability_shifter","mp_weapon_grenade_sonar","mp_weapon_deployable_cover"]
    if ( supported.contains( weaponClass ) )
    {
        array<string> weaponMods = tactical.GetMods()
        bool present = weaponMods.contains( JAMES_TACTICAL_MOD )
        if ( enabled != present )
        {
            if ( enabled ) weaponMods.append( JAMES_TACTICAL_MOD )
            else weaponMods.removebyvalue( JAMES_TACTICAL_MOD )
            tactical.SetMods( weaponMods )
        }
    }
    print( "TACTICAL_RECHARGE: local weapon=" + weaponClass + " enabled=" + enabled
        + " scale=0.50 settings=" + settings )
}
