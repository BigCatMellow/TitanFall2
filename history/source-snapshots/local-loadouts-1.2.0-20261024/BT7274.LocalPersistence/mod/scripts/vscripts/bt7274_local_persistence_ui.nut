global function BT7274LocalPersistence_UIRefresh
void function BT7274LocalPersistence_UIRefresh()
{
    thread BT7274LocalPersistence_CheckMenus()
}
void function BT7274LocalPersistence_CheckMenus()
{
    UpdateCachedLoadouts_Delayed()
    wait 1.5
    entity player = GetUIPlayer()
    if ( !IsValid( player ) ) return
    UpdateAllCachedPilotLoadouts()
    UpdateAllCachedTitanLoadouts()
    uiGlobal.pilotSpawnLoadoutIndex = GetPersistentSpawnLoadoutIndex( player, "pilot" )
    uiGlobal.titanSpawnLoadoutIndex = GetPersistentSpawnLoadoutIndex( player, "titan" )
    int mismatches = 0
    for ( int i = 0; i < NUM_PERSISTENT_PILOT_LOADOUTS; i++ )
    {
        PilotLoadoutDef cache = GetCachedPilotLoadout( i )
        if ( cache.name != GetPersistentLoadoutValue( player, "pilot", i, "name" )
            || cache.primary != GetPersistentLoadoutValue( player, "pilot", i, "primary" )
            || cache.primaryMod1 != GetPersistentLoadoutValue( player, "pilot", i, "primaryMod1" )
            || cache.primaryMod2 != GetPersistentLoadoutValue( player, "pilot", i, "primaryMod2" )
            || cache.primaryAttachment != GetPersistentLoadoutValue( player, "pilot", i, "primaryAttachment" ) ) mismatches++
    }
    int selected = GetPersistentSpawnLoadoutIndex( player, "pilot" )
    PilotLoadoutDef pilot = GetCachedPilotLoadout( selected )
    print( "LOCAL_LOADOUTS_UI: cache_checked mismatches=" + mismatches + " selected=" + selected + " primary=" + pilot.primary + " mod1=" + pilot.primaryMod1 + " mod2=" + pilot.primaryMod2 + " name=" + pilot.name )
}
