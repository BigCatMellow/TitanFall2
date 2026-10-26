global function JamesWeaponHandling_Init
global function JamesWeaponHandling_Apply

const string JAMES_ADS_TRIAL_MOD = "james_solo_ads_trial"
struct { table pending } file

void function JamesWeaponHandling_Init()
{
    AddCallback_OnPlayerRespawned( JamesWeaponHandling_Schedule )
    AddCallback_OnPlayerInventoryChanged( JamesWeaponHandling_Schedule )
    AddCallback_OnPlayerGetsNewPilotLoadout( JamesWeaponHandling_Loadout )
}

void function JamesWeaponHandling_Loadout( entity player, PilotLoadoutDef loadout )
{
    JamesWeaponHandling_Schedule( player )
}

void function JamesWeaponHandling_Schedule( entity player )
{
    if ( !IsValid( player ) ) return
    if ( player in file.pending && file.pending[ player ] ) return
    file.pending[ player ] <- true
    thread JamesWeaponHandling_AfterInventory( player )
}

void function JamesWeaponHandling_AfterInventory( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) ) JamesWeaponHandling_Apply( player )
    file.pending[ player ] <- false
}

void function JamesWeaponHandling_Apply( entity player )
{
    if ( !IsValid( player ) ) return

    bool enabled = IsAlive( player ) && !player.IsTitan() && !IsLobby()
        && player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
        && GetConVarBool( "ns_auth_allow_insecure" )
        && GetConVarBool( "james_ads_trial" )

    array<string> supported = ["mp_weapon_vinson", "mp_weapon_g2"]
    foreach ( entity weapon in player.GetMainWeapons() )
    {
        if ( !IsValid( weapon ) || !supported.contains( weapon.GetWeaponClassName() ) ) continue

        array<string> mods = weapon.GetMods()
        bool present = mods.contains( JAMES_ADS_TRIAL_MOD )
        if ( enabled == present ) continue

        if ( enabled ) mods.append( JAMES_ADS_TRIAL_MOD )
        else mods.removebyvalue( JAMES_ADS_TRIAL_MOD )
        weapon.SetMods( mods )

        print( "WEAPON_HANDLING: weapon=" + weapon.GetWeaponClassName()
            + " enabled=" + enabled + " zoom_scale=0.75" )
    }
}
