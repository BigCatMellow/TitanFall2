global function BT7274ReloadTest_Init
void function BT7274ReloadTest_Init()
{
    AddCallback_GameStateEnter( eGameState.Playing, BT7274ReloadTest_Start )
}
void function BT7274ReloadTest_Start()
{
    thread BT7274ReloadTest_Run()
}
void function BT7274ReloadTest_Run()
{
    wait 1.0
    entity player = null
    foreach ( entity candidate in GetPlayerArray() )
        if ( candidate.GetUID() != "0" ) player = candidate
    Assert( IsValid( player ), "No human for reload test" )
    player.SetInvulnerable()
    PilotLoadoutDef loadout = GetPilotLoadoutFromPersistentData( player, 0 )
    array<int> times = [eWeaponVar.reload_time, eWeaponVar.reload_time_late1,
        eWeaponVar.reload_time_late2, eWeaponVar.reload_time_late3,
        eWeaponVar.reloadempty_time, eWeaponVar.reloadempty_time_late1,
        eWeaponVar.reloadempty_time_late2, eWeaponVar.reloadempty_time_late3]
    foreach ( string gun in ["mp_weapon_g2", "mp_weapon_hemlok_smg", "mp_weapon_rspn101", "mp_weapon_car"] )
    {
        foreach ( bool speedloader in [false, true] )
        {
            SetConVarBool( "bt7274_weapon_reload", false )
            loadout.primary = gun
            loadout.primaryMod1 = speedloader ? "pas_fast_reload" : ""
            loadout.primaryMod2 = speedloader ? "extended_ammo" : ""
            loadout.primaryMod3 = ""
            loadout.primaryAttachment = ""
            UpdateDerivedPilotLoadoutData( loadout )
            GivePilotLoadout( player, loadout )
            wait 0.3
            BT7274WeaponReload_Apply( player )
            entity weapon = player.GetMainWeapons()[0]
            Assert( weapon.GetWeaponClassName() == gun, "Wrong test weapon" )
            array<float> baseline
            foreach ( int field in times ) baseline.append( weapon.GetWeaponSettingFloat( field ) )
            int damage = weapon.GetWeaponSettingInt( eWeaponVar.damage_near_value )
            float rate = weapon.GetWeaponSettingFloat( eWeaponVar.fire_rate )
            float spread = weapon.GetWeaponSettingFloat( eWeaponVar.spread_air_hip )
            int magazine = weapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size )
            weapon.SetWeaponPrimaryClipCount( 3 )
            SetConVarBool( "bt7274_weapon_reload", true )
            BT7274WeaponReload_Apply( player )
            BT7274WeaponReload_Apply( player )
            foreach ( int index, int field in times )
                Assert( fabs( weapon.GetWeaponSettingFloat( field ) - baseline[index] * 0.9 ) < 0.001, "Reload timing mismatch " + gun )
            Assert( weapon.GetWeaponSettingInt( eWeaponVar.damage_near_value ) == damage, "Damage changed" )
            Assert( weapon.GetWeaponSettingFloat( eWeaponVar.fire_rate ) == rate, "Fire rate changed" )
            Assert( weapon.GetWeaponSettingFloat( eWeaponVar.spread_air_hip ) == spread, "Spread changed" )
            Assert( weapon.GetWeaponSettingInt( eWeaponVar.ammo_clip_size ) == magazine, "Magazine changed" )
            Assert( weapon.GetWeaponPrimaryClipCount() == 3, "Applying modifier refilled ammo" )
            Assert( !speedloader || weapon.GetMods().contains( "pas_fast_reload" ), "Speedloader lost" )
            Assert( !speedloader || weapon.GetMods().contains( "extended_ammo" ), "Extended magazine lost" )
            float enabledReload = weapon.GetWeaponSettingFloat( eWeaponVar.reload_time )
            float enabledEmpty = weapon.GetWeaponSettingFloat( eWeaponVar.reloadempty_time )
            SetConVarBool( "bt7274_weapon_reload", false )
            BT7274WeaponReload_Apply( player )
            foreach ( int index, int field in times )
                Assert( fabs( weapon.GetWeaponSettingFloat( field ) - baseline[index] ) < 0.001, "Disable did not restore timing" )
            print( "RELOAD_TEST: PASS map=" + GetMapName() + " gun=" + gun + " speedloader=" + speedloader
                + " reload=" + baseline[0] + "->" + enabledReload + " empty=" + baseline[4] + "->" + enabledEmpty )
        }
    }
    SetConVarBool( "bt7274_weapon_reload", true )
    loadout = GetPilotLoadoutFromPersistentData( player, 0 )
    GivePilotLoadout( player, loadout )
    wait 12.0
    int bots = 0
    bool stripped = false
    foreach ( entity bot in GetPlayerArray() )
    {
        if ( bot.GetUID() != "0" ) continue
        foreach ( entity weapon in bot.GetMainWeapons() )
        {
            Assert( !weapon.GetMods().contains("bt7274_solo_reload"), "Bot got faster reloads" )
            if ( !stripped && weapon.GetWeaponClassName() == "mp_weapon_car" )
            {
                array<string> mods = weapon.GetMods()
                mods.append( "bt7274_solo_reload" )
                weapon.SetMods( mods )
                BT7274WeaponReload_Apply( bot )
                Assert( !weapon.GetMods().contains("bt7274_solo_reload"), "Bot retained transferred modifier" )
                stripped = true
            }
        }
        bots++
    }
    player.ClearInvulnerable()
    print( "RELOAD_TEST: COMPLETE map=" + GetMapName() + " bots_unchanged=" + bots + " bot_strip=" + stripped )
}


