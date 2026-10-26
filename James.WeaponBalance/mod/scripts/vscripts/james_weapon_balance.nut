global function JamesWeaponBalance_Init
global function JamesWeaponBalance_Apply

const string JAMES_ROLE_BALANCE_MOD = "james_role_balance_v1"
struct { table pending } file

void function JamesWeaponBalance_Init()
{
    AddCallback_OnPlayerRespawned( JamesWeaponBalance_Schedule )
    AddCallback_OnPlayerInventoryChanged( JamesWeaponBalance_Schedule )
    AddCallback_OnPlayerGetsNewPilotLoadout( JamesWeaponBalance_Loadout )
}

void function JamesWeaponBalance_Loadout( entity player, PilotLoadoutDef loadout )
{
    JamesWeaponBalance_Schedule( player )
}

void function JamesWeaponBalance_Schedule( entity player )
{
    if ( !IsValid( player ) ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread JamesWeaponBalance_AfterInventory( player )
}

void function JamesWeaponBalance_AfterInventory( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) ) JamesWeaponBalance_Apply( player )
    file.pending[ player ] <- false
}

void function JamesWeaponBalance_Apply( entity player )
{
    if ( !IsValid( player ) ) return

    bool localHuman = player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
    bool testBot = player.GetUID() == "0" && GetConVarBool( "james_weapon_balance_bots" )
    bool enabled = IsAlive( player ) && !player.IsTitan() && !IsLobby()
        && GetConVarBool( "ns_auth_allow_insecure" )
        && GetConVarBool( "james_weapon_balance" )
        && ( localHuman || testBot )

    array<string> supported = ["mp_weapon_vinson", "mp_weapon_hemlok_smg",
        "mp_weapon_r97", "mp_weapon_lmg"]
    foreach ( entity weapon in player.GetMainWeapons() )
    {
        if ( !IsValid( weapon ) || !supported.contains( weapon.GetWeaponClassName() ) ) continue

        array<string> mods = weapon.GetMods()
        bool present = mods.contains( JAMES_ROLE_BALANCE_MOD )
        if ( enabled == present ) continue

        if ( enabled ) mods.append( JAMES_ROLE_BALANCE_MOD )
        else mods.removebyvalue( JAMES_ROLE_BALANCE_MOD )
        weapon.SetMods( mods )

        print( "WEAPON_BALANCE: weapon=" + weapon.GetWeaponClassName()
            + " enabled=" + enabled + " bot=" + ( player.GetUID() == "0" ) )
    }
}
