global function JamesMenuPreviewTest_Init
void function JamesMenuPreviewTest_Init()
{
    if ( !IsLobby() ) AddCallback_GameStateEnter( eGameState.Playing, JamesMenuPreviewTest_Playing )
}
void function JamesMenuPreviewTest_Playing()
{
    thread JamesMenuPreviewTest_ToLobby()
}
void function JamesMenuPreviewTest_ToLobby()
{
    wait 8.0
    print( "MENU_PREVIEW_PROBE: match to post-round lobby" )
    GameRules_ChangeMap( "mp_lobby", "tdm" )
}
