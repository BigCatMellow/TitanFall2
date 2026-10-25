untyped
global function JamesLocalPersistence_Init
global function JamesLocalPersistence_SaveNow

struct {
    table ready
    table signatures
    table snapshots
    table loading
    array<string> paths
} file

void function JamesLocalPersistence_Init()
{
    file.paths = JamesLocalPersistence_Paths( true )
    AddClientCommandCallback( "james_local_ready", JamesLocalPersistence_ClientReadyCommand )
    thread JamesLocalPersistence_WatchLocalPlayer()
    AddCallback_OnClientConnecting( JamesLocalPersistence_OnConnect )
    AddCallback_OnClientConnected( JamesLocalPersistence_OnConnect )
    AddCallback_OnClientDisconnected( JamesLocalPersistence_OnDisconnect )
    foreach ( string command in ["SetPersistentLoadoutValue","SwapSecondaryAndWeapon3PersistentLoadoutData","RequestPilotLoadout","RequestTitanLoadout","LoadoutMenuClosed","InGameMPMenuClosed"] )
        AddClientCommandNotifyCallback( command, JamesLocalPersistence_OnEdit )
}

bool function JamesLocalPersistence_ClientReadyCommand( entity player, array<string> args )
{
    JamesLocalPersistence_OnConnect( player )
    return true
}

void function JamesLocalPersistence_WatchLocalPlayer()
{
    // Private lobby does not run the ordinary connecting/connected callbacks.
    wait 1.0
    while ( true )
    {
        foreach ( entity player in GetPlayerArray() )
            if ( JamesLocalPersistence_IsHuman( player )
                && ( !( player.GetUID() in file.loading ) || file.loading[ player.GetUID() ] != player ) )
                JamesLocalPersistence_OnConnect( player )
        wait 1.0
    }
}

bool function JamesLocalPersistence_IsHuman( entity player )
{
    return IsValid( player ) && player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
        && GetConVarBool( "ns_auth_allow_insecure" ) && GetConVarBool( "james_local_loadouts" )
}

string function JamesLocalPersistence_File( string uid )
{
    return "loadouts_" + uid + ".json"
}

void function JamesLocalPersistence_OnConnect( entity player )
{
    thread JamesLocalPersistence_Load( player )
}

void function JamesLocalPersistence_Load( entity player )
{
    wait 0.5
    if ( !JamesLocalPersistence_IsHuman( player ) )
        return
    string uid = player.GetUID()
    if ( uid in file.loading && file.loading[ uid ] == player ) return
    file.loading[ uid ] <- player
    file.ready[ uid ] <- false
    // Connecting callbacks precede InitPersistentData. Never restore into
    // the uninitialized entity and then have stock initialization reset it.
    float deadline = Time() + 30.0
    while ( IsValid( player ) && player.GetPersistentVarAsInt( "initializedVersion" ) < PERSISTENCE_INIT_VERSION )
    {
        if ( Time() > deadline )
        {
            print( "LOCAL_LOADOUTS: initialization timeout; existing save preserved" )
            return
        }
        wait 0.1
    }
    if ( !JamesLocalPersistence_IsHuman( player ) ) return
    string path = JamesLocalPersistence_File( uid )
    if ( !NSDoesFileExist( path ) )
    {
        print( "LOCAL_LOADOUTS: first local snapshot" )
        JamesLocalPersistence_Start( player )
        return
    }
    NSLoadJSONFile( path, void function( table data ) : ( player, uid )
    {
        if ( !JamesLocalPersistence_IsHuman( player ) )
            return
        if ( !( "version" in data ) || ( data.version != 1 && data.version != 2 ) || !( "owner" in data ) || data.owner != uid || !( "fields" in data ) )
        {
            print( "LOCAL_LOADOUTS: incompatible file preserved; autosave paused" )
            return
        }
        try
        {
            int restored = 0
            foreach ( string path in file.paths )
            {
                if ( !( path in data.fields ) )
                    continue
                player.SetPersistentVar( path, data.fields[ path ] )
                restored++
            }
            SetActivePilotLoadout( player )
            SetActiveTitanLoadout( player )
            player.p.pilotLoadoutChanged = true
            player.p.titanLoadoutChanged = true
            thread UpdateCachedLoadouts()
            file.snapshots[ uid ] <- data
            print( "LOCAL_LOADOUTS: restored " + restored + " named fields" )
            JamesLocalPersistence_Start( player )
        }
        catch ( ex )
        {
            print( "LOCAL_LOADOUTS: restore failed; file preserved and autosave paused: " + string( ex ) )
        }
    }, void function() : ()
    {
        print( "LOCAL_LOADOUTS: existing JSON could not be read; autosave paused" )
    } )
}

void function JamesLocalPersistence_Start( entity player )
{
    file.ready[ player.GetUID() ] <- true
    JamesLocalPersistence_SaveNow( player )
    thread JamesLocalPersistence_SaveLoop( player )
}

void function JamesLocalPersistence_SaveLoop( entity player )
{
    player.EndSignal( "OnDestroy" )
    while ( IsValid( player ) )
    {
        wait 1.0
        if ( IsValid( player ) )
            JamesLocalPersistence_SaveNow( player )
    }
}

void function JamesLocalPersistence_SaveNow( entity player )
{
    // Unattended survey only: restore valid defaults but never save spectator state.
}

void function JamesLocalPersistence_OnEdit( entity player, array<string> args )
{
    thread JamesLocalPersistence_SaveAfterEdit( player )
}

void function JamesLocalPersistence_SaveAfterEdit( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) )
        JamesLocalPersistence_SaveNow( player )
}

void function JamesLocalPersistence_OnDisconnect( entity player )
{
    JamesLocalPersistence_SaveNow( player )
}
