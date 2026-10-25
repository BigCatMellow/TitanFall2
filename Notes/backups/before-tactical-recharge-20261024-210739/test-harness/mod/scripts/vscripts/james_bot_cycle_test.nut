global function JamesBotCycleTest_Init

void function JamesBotCycleTest_Init()
{
    AddCallback_GameStateEnter( eGameState.Playing, JamesBotCycleTest_Start )
    AddCallback_OnClientConnected( JamesPresetProbe )
}

void function JamesPresetProbe( entity player )
{
    thread JamesPresetProbe_Run( player )
}

void function JamesPresetProbe_Run( entity player )
{
    wait 1.5
    if ( !IsValid( player ) )
        return
    if ( player.GetUID() == "0" )
        return
    string name = string( player.GetPersistentVar( "pilotLoadouts[0].name" ) )
    if ( name == "JAMES_LOCAL_SAVE_PROBE" )
    {
        Assert( string( player.GetPersistentVar( "pilotLoadouts[0].primary" ) ) == "mp_weapon_g2", "Saved primary weapon did not restore" )
        print( "LOCAL_PRESET_PROBE: marker restored after reconnect/restart" )
    }
    else
    {
        player.SetPersistentVar( "pilotLoadouts[0].name", "JAMES_LOCAL_SAVE_PROBE" )
        player.SetPersistentVar( "pilotLoadouts[0].primary", "mp_weapon_g2" )
        print( "LOCAL_PRESET_PROBE: marker set; local save layer will capture it" )
    }
}

void function JamesBotCycleTest_Start()
{
    thread JamesBotCycleTest_Run()
}

void function JamesBotCycleTest_Run()
{
    string current = GetMapName()
    wait 75.0
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
        print( "BOT_CYCLE_TEST: finished two map changes; Wargames running" )
    }
}
