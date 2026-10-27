global function BT7274PresetLobbyProbe_Init
void function BT7274PresetLobbyProbe_Init()
{
    AddCallback_OnClientScriptInit( BT7274PresetLobbyProbe_Player )
}
void function BT7274PresetLobbyProbe_Player( entity player )
{
    if ( IsLobby() && player == GetLocalClientPlayer() ) thread BT7274PresetLobbyProbe_Edit( player )
}
void function BT7274PresetLobbyProbe_Edit( entity player )
{
    wait 5.0
    player.ClientCommand( "SetPersistentLoadoutValue pilot 0 name BT7274_LOBBY_EDIT_PROBE" )
    print( "LOCAL_PRESET_PROBE_V12: sent real lobby loadout edit" )
}
