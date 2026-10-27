global function BT7274MenuPreviewTest_Init
void function BT7274MenuPreviewTest_Init()
{
    if ( !IsLobby() ) AddCallback_GameStateEnter( eGameState.Playing, BT7274MenuPreviewTest_Playing )
}
void function BT7274MenuPreviewTest_Playing()
{
    thread BT7274MenuPreviewTest_ToLobby()
}
void function BT7274MenuPreviewTest_ToLobby()
{
    wait 8.0
    print( "MENU_PREVIEW_PROBE: match to post-round lobby" )
    GameRules_ChangeMap( "mp_lobby", "tdm" )
}
