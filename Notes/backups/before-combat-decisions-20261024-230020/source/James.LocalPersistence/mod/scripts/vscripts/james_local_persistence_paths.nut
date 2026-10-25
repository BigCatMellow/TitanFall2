global function JamesLocalPersistence_Paths
array<string> function JamesLocalPersistence_Paths( bool progression = false )
{
    array<string> paths
    array<string> pilots = ["name","suit","race","execution","primary","primaryAttachment","primaryMod1","primaryMod2","primaryMod3","secondary","secondaryMod1","secondaryMod2","secondaryMod3","weapon3","weapon3Mod1","weapon3Mod2","weapon3Mod3","ordnance","passive1","passive2","skinIndex","camoIndex","primarySkinIndex","primaryCamoIndex","secondarySkinIndex","secondaryCamoIndex","weapon3SkinIndex","weapon3CamoIndex"]
    array<string> titans = ["name","titanClass","primaryMod","special","antirodeo","passive1","passive2","passive3","passive4","passive5","passive6","titanExecution","skinIndex","camoIndex","decalIndex","primarySkinIndex","primaryCamoIndex","isPrime","primeSkinIndex","primeCamoIndex","primeDecalIndex","showArmBadge"]
    for ( int i = 0; i < NUM_PERSISTENT_PILOT_LOADOUTS; i++ )
        foreach ( string field in pilots ) paths.append( "pilotLoadouts[" + i + "]." + field )
    for ( int i = 0; i < NUM_PERSISTENT_TITAN_LOADOUTS; i++ )
        foreach ( string field in titans ) paths.append( "titanLoadouts[" + i + "]." + field )
    foreach ( string path in ["pilotSpawnLoadout.index","titanSpawnLoadout.index","factionChoice","burnmeterSlot","activeCallingCardIndex","activeCallsignIconIndex"] ) paths.append( path )
    if ( progression )
    {
        foreach ( string path in ["xp","previousXP","gen","credits","netWorth","doubleXP"] ) paths.append( path )
        foreach ( string root in ["factionXP","previousFactionXP","titanXP","previousTitanXP","fdTitanXP","fdPreviousTitanXP","titanFDUnlockPoints","previousFDUnlockPoints"] )
            for ( int i = 0; i < PersistenceGetArrayCount( root ); i++ ) paths.append( root + "[" + i + "]" )
        foreach ( string root in ["pilotWeapons","titanWeapons"] )
            for ( int i = 0; i < PersistenceGetArrayCount( root ); i++ )
                foreach ( string field in ["weaponXP","previousWeaponXP","proScreenKills","previousProScreenKills","newMods","unlockedMods","newFeatures","unlockedFeatures"] )
                    paths.append( root + "[" + i + "]." + field )
    }
    return paths
}
