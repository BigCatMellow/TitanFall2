global function BT7274WeaponHandling_Init
global function BT7274WeaponHandling_Apply

const string BT7274_ADS_TRIAL_MOD = "bt7274_solo_ads_trial"
struct { table pending } file

void function BT7274WeaponHandling_Init()
{
    AddCallback_OnPlayerRespawned( BT7274WeaponHandling_Schedule )
    AddCallback_OnPlayerInventoryChanged( BT7274WeaponHandling_Schedule )
    AddCallback_OnPlayerGetsNewPilotLoadout( BT7274WeaponHandling_Loadout )
}

void function BT7274WeaponHandling_Loadout( entity player, PilotLoadoutDef loadout )
{
    BT7274WeaponHandling_Schedule( player )
}

void function BT7274WeaponHandling_Schedule( entity player )
{
    if ( !IsValid( player ) ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread BT7274WeaponHandling_AfterInventory( player )
}

void function BT7274WeaponHandling_AfterInventory( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) ) BT7274WeaponHandling_Apply( player )
    file.pending[ player ] <- false
}

void function BT7274WeaponHandling_Apply( entity player )
{
    if ( !IsValid( player ) ) return

    bool enabled = IsAlive( player ) && !player.IsTitan() && !IsLobby()
        && player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
        && GetConVarBool( "ns_auth_allow_insecure" )
        && GetConVarBool( "bt7274_ads_trial" )

    array<string> supported = ["mp_weapon_vinson", "mp_weapon_g2"]
    foreach ( entity weapon in player.GetMainWeapons() )
    {
        if ( !IsValid( weapon ) || !supported.contains( weapon.GetWeaponClassName() ) ) continue

        array<string> mods = weapon.GetMods()
        bool present = mods.contains( BT7274_ADS_TRIAL_MOD )
        if ( enabled == present ) continue

        if ( enabled ) mods.append( BT7274_ADS_TRIAL_MOD )
        else mods.removebyvalue( BT7274_ADS_TRIAL_MOD )
        weapon.SetMods( mods )

        print( "WEAPON_HANDLING: weapon=" + weapon.GetWeaponClassName()
            + " enabled=" + enabled + " zoom_scale=0.75" )
    }
}
