global function BT7274BotLifecycle_Init

void function BT7274BotLifecycle_Init()
{
    SetConVarBool( "bot_manager_round_ready", false )
    AddCallback_GameStateEnter( eGameState.Playing, BT7274BotLifecycle_Ready )
    AddCallback_GameStateEnter( eGameState.SuddenDeath, BT7274BotLifecycle_Ready )
    AddCallback_GameStateEnter( eGameState.WaitingForPlayers, BT7274BotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.PickLoadout, BT7274BotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.Prematch, BT7274BotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.SwitchingSides, BT7274BotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.WinnerDetermined, BT7274BotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.Epilogue, BT7274BotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.Postmatch, BT7274BotLifecycle_NotReady )
    if ( GamePlayingOrSuddenDeath() )
        BT7274BotLifecycle_Ready()
}

void function BT7274BotLifecycle_Ready()
{
    SetConVarBool( "bot_manager_round_ready", true )
    print( "BOT_LIFECYCLE: match playing; bot joins enabled" )
}

void function BT7274BotLifecycle_NotReady()
{
    SetConVarBool( "bot_manager_round_ready", false )
}
