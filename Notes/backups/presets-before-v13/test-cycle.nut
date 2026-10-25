global function JamesBotCycleTest_Init

void function JamesBotCycleTest_Init()
{
    AddCallback_GameStateEnter( eGameState.Playing, JamesBotCycleTest_Start )
}

void function JamesBotCycleTest_Start()
{
    thread JamesBotCycleTest_Run()
}

void function JamesBotCycleTest_Run()
{
    string current = GetMapName()
    wait 75.0
    if ( current == "mp_forwardbase_kodai" )
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
