global function BT7274LocalPersistence_ClientInit
struct { bool watching = false } file
void function BT7274LocalPersistence_ClientInit()
{
    AddCallback_OnClientScriptInit( BT7274LocalPersistence_ClientReady )
}
void function BT7274LocalPersistence_ClientReady( entity player )
{
    if ( player != GetLocalClientPlayer() || file.watching ) return
    file.watching = true
    if ( GetConVarBool( "bt7274_local_loadouts" ) && GetConVarBool( "ns_auth_allow_insecure" ) )
        player.ClientCommand( "bt7274_local_ready" )
    thread BT7274LocalPersistence_WatchMenus( player )
}
void function BT7274LocalPersistence_WatchMenus( entity player )
{
    player.EndSignal( "OnDestroy" )
    array<string> paths = BT7274LocalPersistence_Paths()
    string previous = ""
    wait 2.0
    while ( IsValid( player ) )
    {
        if ( GetConVarBool( "bt7274_local_loadouts" ) && GetConVarBool( "ns_auth_allow_insecure" )
            && player.GetPersistentVarAsInt( "initializedVersion" ) >= PERSISTENCE_INIT_VERSION )
        {
            string signature = ""
            foreach ( string path in paths ) signature += path + "=" + string( player.GetPersistentVar( path ) ) + "\n"
            if ( signature != previous )
            {
                UpdateCachedLoadouts_Delayed()
                RunUIScript( "BT7274LocalPersistence_UIRefresh" )
                previous = signature
                print( "LOCAL_LOADOUTS_CL: refreshing client and menu after networked loadout change" )
            }
        }
        wait 1.0
    }
}
