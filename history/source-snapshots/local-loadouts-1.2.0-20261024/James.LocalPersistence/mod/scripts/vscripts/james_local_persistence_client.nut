global function JamesLocalPersistence_ClientInit
struct { bool watching = false } file
void function JamesLocalPersistence_ClientInit()
{
    AddCallback_OnClientScriptInit( JamesLocalPersistence_ClientReady )
}
void function JamesLocalPersistence_ClientReady( entity player )
{
    if ( player != GetLocalClientPlayer() || file.watching ) return
    file.watching = true
    if ( GetConVarBool( "james_local_loadouts" ) && GetConVarBool( "ns_auth_allow_insecure" ) )
        player.ClientCommand( "james_local_ready" )
    thread JamesLocalPersistence_WatchMenus( player )
}
void function JamesLocalPersistence_WatchMenus( entity player )
{
    player.EndSignal( "OnDestroy" )
    array<string> paths = JamesLocalPersistence_Paths()
    string previous = ""
    wait 2.0
    while ( IsValid( player ) )
    {
        if ( GetConVarBool( "james_local_loadouts" ) && GetConVarBool( "ns_auth_allow_insecure" )
            && player.GetPersistentVarAsInt( "initializedVersion" ) >= PERSISTENCE_INIT_VERSION )
        {
            string signature = ""
            foreach ( string path in paths ) signature += path + "=" + string( player.GetPersistentVar( path ) ) + "\n"
            if ( signature != previous )
            {
                UpdateCachedLoadouts_Delayed()
                RunUIScript( "JamesLocalPersistence_UIRefresh" )
                previous = signature
                print( "LOCAL_LOADOUTS_CL: refreshing client and menu after networked loadout change" )
            }
        }
        wait 1.0
    }
}
