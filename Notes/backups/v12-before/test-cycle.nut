global function BT7274BotCycleTest_Init

void function BT7274BotCycleTest_Init()
{
    AddCallback_GameStateEnter( eGameState.Playing, BT7274BotCycleTest_Start )
}

void function BT7274BotCycleTest_Start()
{
    thread BT7274BotCycleTest_Run()
}

void function BT7274BotCycleTest_Run()
{
    string current = GetMapName()
    wait ( current == "mp_forwardbase_kodai" ? 75.0 : 45.0 )
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
