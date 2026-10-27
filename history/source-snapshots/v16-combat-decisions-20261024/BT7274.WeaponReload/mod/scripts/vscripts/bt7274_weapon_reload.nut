global function BT7274WeaponReload_Init
global function BT7274WeaponReload_Apply
const string BT7274_RELOAD_MOD = "bt7274_solo_reload"
struct { table pending } file

void function BT7274WeaponReload_Init()
{
    AddCallback_OnPlayerRespawned( BT7274WeaponReload_Schedule )
    AddCallback_OnPlayerInventoryChanged( BT7274WeaponReload_Schedule )
    AddCallback_OnPlayerGetsNewPilotLoadout( BT7274WeaponReload_Loadout )
}
void function BT7274WeaponReload_Loadout( entity player, PilotLoadoutDef loadout )
{
    BT7274WeaponReload_Schedule( player )
}
void function BT7274WeaponReload_Schedule( entity player )
{
    if ( !IsValid( player ) ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread BT7274WeaponReload_AfterInventory( player )
}
void function BT7274WeaponReload_AfterInventory( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) ) BT7274WeaponReload_Apply( player )
    file.pending[ player ] <- false
}
void function BT7274WeaponReload_Apply( entity player )
{
    if ( !IsValid( player ) ) return
    bool enabled = IsAlive( player ) && !player.IsTitan() && !IsLobby()
        && player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
        && GetConVarBool( "ns_auth_allow_insecure" )
        && GetConVarBool( "bt7274_weapon_reload" )
    array<string> supported = ["mp_weapon_g2", "mp_weapon_hemlok_smg",
        "mp_weapon_rspn101", "mp_weapon_car"]
    foreach ( entity weapon in player.GetMainWeapons() )
    {
        if ( !IsValid( weapon ) || !supported.contains( weapon.GetWeaponClassName() ) ) continue
        array<string> mods = weapon.GetMods()
        bool present = mods.contains( BT7274_RELOAD_MOD )
        if ( enabled == present ) continue
        if ( enabled ) mods.append( BT7274_RELOAD_MOD )
        else mods.removebyvalue( BT7274_RELOAD_MOD )
        weapon.SetMods( mods )
        print( "WEAPON_RELOAD: weapon=" + weapon.GetWeaponClassName()
            + " enabled=" + enabled + " time_scale=0.90" )
    }
}
