global function JamesWeaponReload_Init
global function JamesWeaponReload_Apply
const string JAMES_RELOAD_MOD = "james_solo_reload"
struct { table pending } file

void function JamesWeaponReload_Init()
{
    AddCallback_OnPlayerRespawned( JamesWeaponReload_Schedule )
    AddCallback_OnPlayerInventoryChanged( JamesWeaponReload_Schedule )
    AddCallback_OnPlayerGetsNewPilotLoadout( JamesWeaponReload_Loadout )
}
void function JamesWeaponReload_Loadout( entity player, PilotLoadoutDef loadout )
{
    JamesWeaponReload_Schedule( player )
}
void function JamesWeaponReload_Schedule( entity player )
{
    if ( !IsValid( player ) ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread JamesWeaponReload_AfterInventory( player )
}
void function JamesWeaponReload_AfterInventory( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) ) JamesWeaponReload_Apply( player )
    file.pending[ player ] <- false
}
void function JamesWeaponReload_Apply( entity player )
{
    if ( !IsValid( player ) ) return
    bool enabled = IsAlive( player ) && !player.IsTitan() && !IsLobby()
        && player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
        && GetConVarBool( "ns_auth_allow_insecure" )
        && GetConVarBool( "james_weapon_reload" )
    // hemlok_smg is the Volt, not the Alternator. Keep the existing Volt buff
    // and include the actual Alternator class rather than silently removing it.
    array<string> supported = ["mp_weapon_g2", "mp_weapon_hemlok_smg",
        "mp_weapon_alternator_smg", "mp_weapon_rspn101", "mp_weapon_car"]
    foreach ( entity weapon in player.GetMainWeapons() )
    {
        if ( !IsValid( weapon ) || !supported.contains( weapon.GetWeaponClassName() ) ) continue
        array<string> mods = weapon.GetMods()
        bool present = mods.contains( JAMES_RELOAD_MOD )
        if ( enabled == present ) continue
        if ( enabled ) mods.append( JAMES_RELOAD_MOD )
        else mods.removebyvalue( JAMES_RELOAD_MOD )
        weapon.SetMods( mods )
        print( "WEAPON_RELOAD: weapon=" + weapon.GetWeaponClassName()
            + " enabled=" + enabled + " time_scale=0.90" )
    }
}
