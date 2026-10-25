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
    wait 25.0
    string current = GetMapName()
    if ( current == "mp_eden" )
    {
        print( "BOT_CYCLE_TEST: Eden to Relic" )
        GameRules_ChangeMap( "mp_relic02", "tdm" )
    }
    else if ( current == "mp_relic02" )
    {
        print( "BOT_CYCLE_TEST: Relic to Wargames" )
        GameRules_ChangeMap( "mp_wargames", "tdm" )
    }
    else if ( current == "mp_wargames" )
    {
        print( "BOT_CYCLE_TEST: finished two map changes; Wargames running" )
    }
}
