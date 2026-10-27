untyped
global function BT7274LocalPersistence_Init
global function BT7274LocalPersistence_SaveNow

struct {
    table ready
    table signatures
    table snapshots
    table loading
    array<string> paths
} file

void function BT7274LocalPersistence_Init()
{
    file.paths = BT7274LocalPersistence_Paths( true )
    AddClientCommandCallback( "bt7274_local_ready", BT7274LocalPersistence_ClientReadyCommand )
    thread BT7274LocalPersistence_WatchLocalPlayer()
    AddCallback_OnClientConnecting( BT7274LocalPersistence_OnConnect )
    AddCallback_OnClientConnected( BT7274LocalPersistence_OnConnect )
    AddCallback_OnClientDisconnected( BT7274LocalPersistence_OnDisconnect )
    foreach ( string command in ["SetPersistentLoadoutValue","SwapSecondaryAndWeapon3PersistentLoadoutData","RequestPilotLoadout","RequestTitanLoadout","LoadoutMenuClosed","InGameMPMenuClosed"] )
        AddClientCommandNotifyCallback( command, BT7274LocalPersistence_OnEdit )
}

bool function BT7274LocalPersistence_ClientReadyCommand( entity player, array<string> args )
{
    BT7274LocalPersistence_OnConnect( player )
    return true
}

void function BT7274LocalPersistence_WatchLocalPlayer()
{
    // Private lobby does not run the ordinary connecting/connected callbacks.
    wait 1.0
    while ( true )
    {
        foreach ( entity player in GetPlayerArray() )
            if ( BT7274LocalPersistence_IsHuman( player )
                && ( !( player.GetUID() in file.loading ) || file.loading[ player.GetUID() ] != player ) )
                BT7274LocalPersistence_OnConnect( player )
        wait 1.0
    }
}

bool function BT7274LocalPersistence_IsHuman( entity player )
{
    return IsValid( player ) && player.GetUID() != "0" && NSIsPlayerLocalPlayer( player )
        && GetConVarBool( "ns_auth_allow_insecure" ) && GetConVarBool( "bt7274_local_loadouts" )
}

string function BT7274LocalPersistence_File( string uid )
{
    return "loadouts_" + uid + ".json"
}

void function BT7274LocalPersistence_OnConnect( entity player )
{
    thread BT7274LocalPersistence_Load( player )
}

void function BT7274LocalPersistence_Load( entity player )
{
    wait 0.5
    if ( !BT7274LocalPersistence_IsHuman( player ) )
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
    if ( !BT7274LocalPersistence_IsHuman( player ) ) return
    string path = BT7274LocalPersistence_File( uid )
    if ( !NSDoesFileExist( path ) )
    {
        print( "LOCAL_LOADOUTS: first local snapshot" )
        BT7274LocalPersistence_Start( player )
        return
    }
    NSLoadJSONFile( path, void function( table data ) : ( player, uid )
    {
        if ( !BT7274LocalPersistence_IsHuman( player ) )
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
            BT7274LocalPersistence_Start( player )
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

void function BT7274LocalPersistence_Start( entity player )
{
    file.ready[ player.GetUID() ] <- true
    BT7274LocalPersistence_SaveNow( player )
    thread BT7274LocalPersistence_SaveLoop( player )
}

void function BT7274LocalPersistence_SaveLoop( entity player )
{
    player.EndSignal( "OnDestroy" )
    while ( IsValid( player ) )
    {
        wait 1.0
        if ( IsValid( player ) )
            BT7274LocalPersistence_SaveNow( player )
    }
}

void function BT7274LocalPersistence_SaveNow( entity player )
{
    if ( !BT7274LocalPersistence_IsHuman( player ) )
        return
    string uid = player.GetUID()
    if ( !( uid in file.ready ) || !file.ready[ uid ] )
        return
    table fields = {}
    string signature = ""
    foreach ( string path in file.paths )
    {
        var value = player.GetPersistentVar( path )
        // Empty enum entries are returned as null; Northstar's JSON encoder
        // drops nulls. Stock loadout helpers represent those entries as "".
        if ( value == null )
            value = ""
        fields[ path ] <- value
        signature += path + "=" + string( value ) + "\n"
    }
    if ( uid in file.signatures && file.signatures[ uid ] == signature )
        return
    table data = { version = 2, owner = uid, fields = fields }
    if ( uid in file.snapshots )
        NSSaveJSONFile( "previous_" + uid + ".json", file.snapshots[ uid ] )
    NSSaveJSONFile( BT7274LocalPersistence_File( uid ), data )
    file.snapshots[ uid ] <- data
    file.signatures[ uid ] <- signature
    print( "LOCAL_LOADOUTS: saved " + file.paths.len() + " named fields" )
}

void function BT7274LocalPersistence_OnEdit( entity player, array<string> args )
{
    thread BT7274LocalPersistence_SaveAfterEdit( player )
}

void function BT7274LocalPersistence_SaveAfterEdit( entity player )
{
    WaitEndFrame()
    if ( IsValid( player ) )
        BT7274LocalPersistence_SaveNow( player )
}

void function BT7274LocalPersistence_OnDisconnect( entity player )
{
    BT7274LocalPersistence_SaveNow( player )
}
