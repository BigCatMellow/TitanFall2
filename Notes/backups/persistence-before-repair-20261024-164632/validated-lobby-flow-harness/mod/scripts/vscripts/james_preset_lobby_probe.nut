global function JamesPresetLobbyProbe_Init
void function JamesPresetLobbyProbe_Init()
{
    AddCallback_OnClientScriptInit( JamesPresetLobbyProbe_Player )
}
void function JamesPresetLobbyProbe_Player( entity player )
{
    if ( IsLobby() && player == GetLocalClientPlayer() ) thread JamesPresetLobbyProbe_Edit( player )
}
void function JamesPresetLobbyProbe_Edit( entity player )
{
    wait 5.0
    player.ClientCommand( "SetPersistentLoadoutValue pilot 0 name JAMES_LOBBY_EDIT_PROBE" )
    print( "LOCAL_PRESET_PROBE_V12: sent real lobby loadout edit" )
}
