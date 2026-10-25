global function JamesBotLifecycle_Init

void function JamesBotLifecycle_Init()
{
    SetConVarBool( "bot_manager_round_ready", false )
    AddCallback_GameStateEnter( eGameState.Playing, JamesBotLifecycle_Ready )
    AddCallback_GameStateEnter( eGameState.SuddenDeath, JamesBotLifecycle_Ready )
    AddCallback_GameStateEnter( eGameState.WaitingForPlayers, JamesBotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.PickLoadout, JamesBotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.Prematch, JamesBotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.SwitchingSides, JamesBotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.WinnerDetermined, JamesBotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.Epilogue, JamesBotLifecycle_NotReady )
    AddCallback_GameStateEnter( eGameState.Postmatch, JamesBotLifecycle_NotReady )
    if ( GamePlayingOrSuddenDeath() )
        JamesBotLifecycle_Ready()
}

void function JamesBotLifecycle_Ready()
{
    SetConVarBool( "bot_manager_round_ready", true )
    print( "BOT_LIFECYCLE: match playing; bot joins enabled" )
}

void function JamesBotLifecycle_NotReady()
{
    SetConVarBool( "bot_manager_round_ready", false )
}
