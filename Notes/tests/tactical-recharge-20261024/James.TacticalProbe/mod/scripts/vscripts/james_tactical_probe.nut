global function JamesTacticalProbe_Init
struct { bool started = false } file
void function JamesTacticalProbe_Init()
{
    AddCallback_GameStateEnter( eGameState.Playing, JamesTacticalProbe_Start )
}
void function JamesTacticalProbe_Start()
{
    if ( file.started ) return
    file.started = true
    thread JamesTacticalProbe_Run()
}
float function JamesTacticalProbe_Fill( entity player )
{
    player.SetSuitGrapplePower( 0.0 )
    float start = Time()
    while ( player.GetSuitGrapplePower() < 99.9 && Time() - start < 40.0 )
        wait 0.05
    return Time() - start
}
void function JamesTacticalProbe_Run()
{
    wait 1.0
    entity player = null
    foreach ( entity candidate in GetPlayerArray() )
        if ( candidate.GetUID() != "0" ) player = candidate
    if ( !IsValid( player ) ) { print( "TACTICAL_TEST: FAIL no human" ); return }
    player.SetInvulnerable()
    PilotLoadoutDef loadout = GetPilotLoadoutFromPersistentData( player, 0 )
    array<string> suits = ["light", "stalker", "nomad", "geist", "medium", "heavy", "grapple"]
    foreach ( string suit in suits )
    {
        loadout.suit = suit
        loadout.passive1 = "pas_power_cell"
        UpdateDerivedPilotLoadoutData( loadout )
        SetConVarBool( "james_tactical_recharge", false )
        GivePilotLoadout( player, loadout )
        wait 0.5
        JamesTacticalRecharge_Apply( player )
        entity tactical = player.GetOffhandWeapon( OFFHAND_LEFT )
        entity ordnance = player.GetOffhandWeapon( OFFHAND_RIGHT )
        float ordnanceRate = ordnance.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate )
        string weapon = tactical.GetWeaponClassName()
        if ( weapon == "mp_ability_grapple" )
        {
            wait 4.0
            float baselineTime = JamesTacticalProbe_Fill( player )
            SetConVarBool( "james_tactical_recharge", true )
            JamesTacticalRecharge_Apply( player )
            JamesTacticalRecharge_Apply( player )
            wait 4.0
            float halfTime = JamesTacticalProbe_Fill( player )
            array<string> mods = player.GetPlayerSettingsMods()
            bool pass = halfTime > 0.0 && fabs( halfTime / baselineTime - 0.5 ) < 0.06
                && mods.contains( "pas_power_cell" ) && mods.contains( "james_tactical_recharge" )
            print( "TACTICAL_TEST: " + (pass ? "PASS" : "FAIL") + " grapple base=" + baselineTime + " half=" + halfTime + " power_cell=" + mods.contains("pas_power_cell") )
            SetConVarBool( "james_tactical_recharge", false )
            JamesTacticalRecharge_Apply( player )
            Assert( !player.GetPlayerSettingsMods().contains( "james_tactical_recharge" ), "grapple modifier did not remove" )
        }
        else
        {
            float baseline = tactical.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate )
            float delay = tactical.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_start_delay )
            float duration = tactical.GetWeaponSettingFloat( eWeaponVar.fire_duration )
            int maxAmmo = tactical.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )
            SetConVarBool( "james_tactical_recharge", true )
            JamesTacticalRecharge_Apply( player )
            JamesTacticalRecharge_Apply( player )
            wait 0.1
            float actual = tactical.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate )
            bool pass = fabs( actual - baseline * 2.0 ) < 0.01
                && fabs( tactical.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_start_delay ) - delay * 0.5 ) < 0.01
                && tactical.GetWeaponSettingFloat( eWeaponVar.fire_duration ) == duration
                && tactical.GetWeaponSettingInt( eWeaponVar.ammo_clip_size ) == maxAmmo
                && ordnance.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate ) == ordnanceRate
            SetConVarBool( "james_tactical_recharge", false )
            JamesTacticalRecharge_Apply( player )
            pass = pass && fabs( tactical.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate ) - baseline ) < 0.01
            print( "TACTICAL_TEST: " + (pass ? "PASS" : "FAIL") + " " + weapon + " base_rate=" + baseline + " half_rate=" + actual + " duration=" + duration + " ammo=" + maxAmmo )
        }
    }
    loadout = GetPilotLoadoutFromPersistentData( player, 0 )
    SetConVarBool( "james_tactical_recharge", true )
    GivePilotLoadout( player, loadout )
    wait 2.0
    int checkedBots = 0
    foreach ( entity bot in GetPlayerArray() )
    {
        if ( bot.GetUID() != "0" ) continue
        Assert( !bot.GetPlayerSettingsMods().contains( "james_tactical_recharge" ), "bot received player modifier" )
        entity ability = bot.GetOffhandWeapon( OFFHAND_LEFT )
        if ( IsValid( ability ) ) Assert( !ability.GetMods().contains( "james_tactical_recharge" ), "bot received tactical modifier" )
        checkedBots++
    }
    player.ClearInvulnerable()
    print( "TACTICAL_TEST: COMPLETE bots_unchanged=" + checkedBots )
}
