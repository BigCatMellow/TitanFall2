untyped
global function JamesBotDecisions_Init

void function JamesBotDecisions_Init()
{
    print( "BOT_DECISIONS: bridge v1 ready; native readiness/target reporting only" )
    thread JamesBotDecisions_Update()
}
float function JamesBotDecisions_Cost( entity weapon )
{
    return max( 1, max( weapon.GetAmmoPerShot(), weapon.GetWeaponCurrentEnergyCost() ) )
}
bool function JamesBotDecisions_Ready( entity weapon )
{
    if ( !IsValid( weapon ) ) return false
    return weapon.IsReadyToFire() && !weapon.IsWeaponRegenDraining()
        && weapon.GetWeaponPrimaryClipCount() >= JamesBotDecisions_Cost( weapon )
}
void function JamesBotDecisions_Update()
{
    float nextLog = 0.0
    while ( true )
    {
        bool emit = Time() >= nextLog
        if ( emit ) nextLog = Time() + 2.0
        foreach ( entity player in GetPlayerArray() )
        {
            if ( !IsValid( player ) ) continue
            entity pet = player.GetPetTitan()
            if ( IsValid( pet ) && IsAlive( pet ) )
                BotReportTargetEligibility( pet, !pet.e.isHotDropping, Time() )
            if ( player.GetUID() != "0" || !IsAlive( player ) || player.IsTitan() ) continue
            entity tactical = player.GetOffhandWeapon( OFFHAND_LEFT )
            entity ordnance = player.GetOffhandWeapon( OFFHAND_RIGHT )
            bool tacReady = JamesBotDecisions_Ready( tactical )
            bool ordReady = JamesBotDecisions_Ready( ordnance )
            BotReportReadiness( player, tactical, tacReady, ordnance, ordReady, Time() )
            if ( emit && IsValid( tactical ) && IsValid( ordnance ) )
                print( "BOT_READY map=" + GetMapName() + " t=" + Time() + " entity_index=" + player.GetEntIndex()
                    + " tactical=" + tactical.GetWeaponClassName() + " tactical_ready=" + tacReady
                    + " tactical_clip=" + tactical.GetWeaponPrimaryClipCount() + " tactical_shots=" + tactical.GetShotCount()
                    + " tactical_cost=" + JamesBotDecisions_Cost( tactical )
                    + " ordnance=" + ordnance.GetWeaponClassName() + " ordnance_ready=" + ordReady
                    + " ordnance_clip=" + ordnance.GetWeaponPrimaryClipCount() + " ordnance_shots=" + ordnance.GetShotCount()
                    + " ordnance_cost=" + JamesBotDecisions_Cost( ordnance ) )
        }
        wait 0.1
    }
}
