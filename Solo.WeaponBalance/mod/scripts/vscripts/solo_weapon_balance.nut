global function SoloWeaponBalance_Init
global function SoloWeaponBalance_Apply

const string SOLO_ROLE_BALANCE_MOD = "solo_role_balance_v1"
struct { table pending } file

void function SoloWeaponBalance_Init()
{
    AddCallback_OnPlayerRespawned( SoloWeaponBalance_Schedule )
    AddCallback_OnPlayerInventoryChanged( SoloWeaponBalance_Schedule )
    AddCallback_OnPlayerGetsNewPilotLoadout( SoloWeaponBalance_Loadout )
}

void function SoloWeaponBalance_Loadout( entity player, PilotLoadoutDef loadout )
{
    SoloWeaponBalance_Schedule( player )
}

void function SoloWeaponBalance_Schedule( entity player )
{
    if ( !IsValid( player ) ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread SoloWeaponBalance_AfterInventory( player )
}

void function SoloWeaponBalance_AfterInventory( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) ) SoloWeaponBalance_Apply( player )
    file.pending[ player ] <- false
}

void function SoloWeaponBalance_Apply( entity player )
{
    if ( !IsValid( player ) ) return

    bool localHuman = player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
    bool testBot = player.GetUID() == "0" && GetConVarBool( "solo_weapon_balance_bots" )
    bool enabled = IsAlive( player ) && !player.IsTitan() && !IsLobby()
        && GetConVarBool( "ns_auth_allow_insecure" )
        && GetConVarBool( "solo_weapon_balance" )
        && ( localHuman || testBot )

    array<string> supported = ["mp_weapon_vinson", "mp_weapon_hemlok_smg",
        "mp_weapon_r97", "mp_weapon_lmg"]
    foreach ( entity weapon in player.GetMainWeapons() )
    {
        if ( !IsValid( weapon ) || !supported.contains( weapon.GetWeaponClassName() ) ) continue

        array<string> mods = weapon.GetMods()
        bool present = mods.contains( SOLO_ROLE_BALANCE_MOD )
        if ( enabled == present ) continue

        if ( enabled ) mods.append( SOLO_ROLE_BALANCE_MOD )
        else mods.removebyvalue( SOLO_ROLE_BALANCE_MOD )
        weapon.SetMods( mods )

        print( "WEAPON_BALANCE: weapon=" + weapon.GetWeaponClassName()
            + " enabled=" + enabled + " bot=" + ( player.GetUID() == "0" ) )
    }
}
