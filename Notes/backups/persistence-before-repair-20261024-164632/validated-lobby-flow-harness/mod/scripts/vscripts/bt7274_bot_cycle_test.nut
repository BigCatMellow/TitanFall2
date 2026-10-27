global function BT7274BotCycleTest_Init

void function BT7274BotCycleTest_Init()
{
    AddCallback_GameStateEnter( eGameState.Playing, BT7274BotCycleTest_Start )
    AddCallback_OnClientConnected( BT7274PresetProbe )
    if ( IsLobby() ) thread BT7274PresetLobbyToRise()
}

void function BT7274PresetLobbyToRise()
{
    wait 15.0
    print( "LOCAL_PRESET_PROBE_V12: lobby to Rise" )
    GameRules_ChangeMap( "mp_rise", "tdm" )
}

void function BT7274PresetProbe( entity player )
{
    thread BT7274PresetProbe_Run( player )
}

void function BT7274PresetProbe_Run( entity player )
{
    wait 1.5
    if ( !IsValid( player ) )
        return
    if ( player.GetUID() == "0" )
        return
    string name = string( player.GetPersistentVar( "pilotLoadouts[0].name" ) )
    if ( name == "BT7274_LOCAL_SAVE_PROBE_V12" || name == "BT7274_LOBBY_EDIT_PROBE" )
    {
        Assert( string( player.GetPersistentVar( "pilotLoadouts[0].primary" ) ) == "mp_weapon_car", "Saved primary weapon did not restore" )
        Assert( string( player.GetPersistentVar( "pilotLoadouts[0].primaryMod1" ) ) == "extended_ammo", "Saved attachment did not restore" )
        Assert( string( player.GetPersistentVar( "pilotLoadouts[0].primaryMod2" ) ) == "pas_fast_reload", "Saved second mod did not restore" )
        Assert( player.GetPersistentVarAsInt( "xp" ) == 137, "Saved XP did not restore" )
        Assert( player.GetPersistentVarAsInt( "gen" ) == 2, "Saved generation did not restore" )
        Assert( player.GetPersistentVarAsInt( "pilotWeapons[0].weaponXP" ) == 71, "Saved weapon XP did not restore" )
        print( "LOCAL_PRESET_PROBE_V12: restored name, weapon, attachments, XP, generation and weapon XP" )
    }
    else
    {
        player.SetPersistentVar( "pilotLoadouts[0].name", "BT7274_LOCAL_SAVE_PROBE_V12" )
        player.SetPersistentVar( "pilotLoadouts[0].primary", "mp_weapon_car" )
        player.SetPersistentVar( "pilotLoadouts[0].primaryMod1", "extended_ammo" )
        player.SetPersistentVar( "pilotLoadouts[0].primaryMod2", "pas_fast_reload" )
        player.SetPersistentVar( "pilotLoadouts[0].primaryAttachment", "" )
        player.SetPersistentVar( "xp", 137 )
        player.SetPersistentVar( "gen", 2 )
        player.SetPersistentVar( "pilotWeapons[0].weaponXP", 71 )
        print( "LOCAL_PRESET_PROBE_V12: test loadout and XP set for saving" )
    }
}

void function BT7274BotCycleTest_Start()
{
    thread BT7274BotCycleTest_Run()
}

void function BT7274BotCycleTest_Run()
{
    string current = GetMapName()
    wait ( current == "mp_wargames" ? 10.0 : 75.0 )
    if ( current == "mp_eden" )
    {
        print( "BOT_CYCLE_TEST: Eden recovery test to Wargames" )
        GameRules_ChangeMap( "mp_wargames", "tdm" )
    }
    else if ( current == "mp_forwardbase_kodai" )
    {
        print( "BOT_CYCLE_TEST: Kodai movement test to Relic" )
        GameRules_ChangeMap( "mp_relic02", "tdm" )
    }
    else if ( current == "mp_relic02" )
    {
        print( "BOT_CYCLE_TEST: Relic movement test to Wargames" )
        GameRules_ChangeMap( "mp_wargames", "tdm" )
    }
    else if ( current == "mp_wargames" )
    {
        print( "LOCAL_PRESET_PROBE_V12: Wargames to lobby" )
        GameRules_ChangeMap( "mp_lobby", "tdm" )
    }
}
