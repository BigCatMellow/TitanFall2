global function JamesBotCycleTest_Init
void function JamesBotCycleTest_Init()
{
    SetConVarBool( "bot_combat_decisions", GetMapName() != "mp_eden" )
    if ( GetMapName() == "mp_wargames" ) SetConVarString( "bot_force_pilot_primary", "mp_weapon_shotgun" )
    AddCallback_GameStateEnter( eGameState.Playing, JamesCombatTest_Start )
}
void function JamesCombatTest_Start()
{
    thread JamesCombatTest_Run()
    thread JamesCombatTest_Snapshot()
}
void function JamesCombatTest_Snapshot()
{
    while ( true )
    {
        foreach ( entity player in GetPlayerArray() )
        {
            if ( player.GetUID() != "0" || !IsAlive(player) || player.IsTitan() ) continue
            entity weapon = player.GetActiveWeapon()
            if ( !IsValid(weapon) ) continue
            print( "COMBAT_PROBE: t=" + Time() + " id=" + player.GetEncodedEHandle()
                + " name=" + player.GetPlayerName() + " weapon=" + weapon.GetWeaponClassName()
                + " clip=" + weapon.GetWeaponPrimaryClipCount() )
        }
        wait 2.0
    }
}
void function JamesCombatTest_Drain()
{
    foreach ( entity player in GetPlayerArray() )
    {
        if ( player.GetUID() != "0" || !IsAlive(player) || player.IsTitan() ) continue
        entity weapon = player.GetActiveWeapon()
        if ( !IsValid(weapon) || !["mp_weapon_car", "mp_weapon_rspn101", "mp_weapon_hemlok_smg", "mp_weapon_g2", "mp_weapon_shotgun"].contains(weapon.GetWeaponClassName()) ) continue
        if ( weapon.GetWeaponPrimaryClipCount() < 4 ) continue
        print( "COMBAT_TEST: draining clip for reload id=" + player.GetEncodedEHandle() + " name=" + player.GetPlayerName() + " weapon=" + weapon.GetWeaponClassName() )
        weapon.SetWeaponPrimaryClipCount(0)
        thread JamesCombatTest_CheckReload(player, weapon)
        return
    }
    print( "COMBAT_TEST: no eligible active rifle/SMG for forced reload" )
}
void function JamesCombatTest_CheckReload( entity player, entity weapon )
{
    float deadline = Time() + 7.0
    while ( Time() < deadline && IsValid(player) && IsAlive(player) && IsValid(weapon) )
    {
        if ( weapon.GetWeaponPrimaryClipCount() > 0 )
        {
            print( "COMBAT_TEST: PASS native reload replenished clip name=" + player.GetPlayerName() )
            return
        }
        wait 0.1
    }
    print( "COMBAT_TEST: reload probe interrupted or timed out" )
}
void function JamesCombatTest_Run()
{
    if ( GetMapName() == "mp_eden" )
    {
        print( "COMBAT_TEST: Eden baseline combat_decisions=0" )
        wait 40.0
        SetConVarBool( "bot_combat_decisions", true )
        print( "COMBAT_TEST: Eden enabled combat_decisions=1" )
        wait 8.0
        JamesCombatTest_Drain()
        wait 57.0
        print( "COMBAT_TEST: Eden complete; changing to Wargames" )
        GameRules_ChangeMap( "mp_wargames", "tdm" )
    }
    else
    {
        print( "COMBAT_TEST: Wargames enabled combat_decisions=1" )
        wait 12.0
        JamesCombatTest_Drain()
        wait 23.0
        SetConVarString( "bot_force_pilot_primary", "mp_weapon_g2" )
        print( "COMBAT_TEST: Wargames next spawns use G2" )
        wait 40.0
        print( "COMBAT_TEST: COMPLETE two maps and runtime toggle" )
    }
}
