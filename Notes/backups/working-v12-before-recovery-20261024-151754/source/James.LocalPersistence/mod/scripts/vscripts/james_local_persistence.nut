untyped
global function JamesLocalPersistence_Init
global function JamesLocalPersistence_SaveNow

struct {
    table ready
    table signatures
    table snapshots
    array<string> paths
} file

void function JamesLocalPersistence_Init()
{
    array<string> pilots = ["name","suit","race","execution","primary","primaryAttachment","primaryMod1","primaryMod2","primaryMod3","secondary","secondaryMod1","secondaryMod2","secondaryMod3","weapon3","weapon3Mod1","weapon3Mod2","weapon3Mod3","ordnance","passive1","passive2","skinIndex","camoIndex","primarySkinIndex","primaryCamoIndex","secondarySkinIndex","secondaryCamoIndex","weapon3SkinIndex","weapon3CamoIndex"]
    array<string> titans = ["name","titanClass","primaryMod","special","antirodeo","passive1","passive2","passive3","passive4","passive5","passive6","titanExecution","skinIndex","camoIndex","decalIndex","primarySkinIndex","primaryCamoIndex","isPrime","primeSkinIndex","primeCamoIndex","primeDecalIndex","showArmBadge"]
    for ( int i = 0; i < NUM_PERSISTENT_PILOT_LOADOUTS; i++ )
        foreach ( string field in pilots )
            file.paths.append( "pilotLoadouts[" + i + "]." + field )
    for ( int i = 0; i < NUM_PERSISTENT_TITAN_LOADOUTS; i++ )
        foreach ( string field in titans )
            file.paths.append( "titanLoadouts[" + i + "]." + field )
    foreach ( string path in ["pilotSpawnLoadout.index","titanSpawnLoadout.index","factionChoice","burnmeterSlot","activeCallingCardIndex","activeCallsignIconIndex"] )
        file.paths.append( path )
    AddCallback_OnClientConnecting( JamesLocalPersistence_OnConnect )
    AddCallback_OnClientDisconnected( JamesLocalPersistence_OnDisconnect )
    foreach ( string command in ["SetPersistentLoadoutValue","SwapSecondaryAndWeapon3PersistentLoadoutData","RequestPilotLoadout","RequestTitanLoadout","LoadoutMenuClosed","InGameMPMenuClosed"] )
        AddClientCommandNotifyCallback( command, JamesLocalPersistence_OnEdit )
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
    file.ready[ uid ] <- false
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
        if ( !( "version" in data ) || data.version != 1 || !( "owner" in data ) || data.owner != uid || !( "fields" in data ) )
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
    if ( !JamesLocalPersistence_IsHuman( player ) )
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
    table data = { version = 1, owner = uid, fields = fields }
    if ( uid in file.snapshots )
        NSSaveJSONFile( "previous_" + uid + ".json", file.snapshots[ uid ] )
    NSSaveJSONFile( JamesLocalPersistence_File( uid ), data )
    file.snapshots[ uid ] <- data
    file.signatures[ uid ] <- signature
    print( "LOCAL_LOADOUTS: saved " + file.paths.len() + " named fields" )
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
