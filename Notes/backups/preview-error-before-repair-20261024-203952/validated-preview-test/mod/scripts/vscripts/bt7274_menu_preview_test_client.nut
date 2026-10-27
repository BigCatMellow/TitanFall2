global function BT7274MenuPreviewTest_ClientInit
void function BT7274MenuPreviewTest_ClientInit()
{
    AddCallback_OnClientScriptInit( BT7274MenuPreviewTest_ClientReady )
}
void function BT7274MenuPreviewTest_ClientReady( entity player )
{
    if ( IsLobby() && player == GetLocalClientPlayer() ) thread BT7274MenuPreviewTest_Run( player )
}
void function BT7274MenuPreviewTest_Run( entity player )
{
    player.EndSignal( "OnDestroy" )
    wait 5.0
    float deadline = Time() + 20.0
    while ( !clGlobal.initializedMenuModels )
    {
        if ( Time() > deadline ) { print( "MENU_PREVIEW_PROBE: FAIL models did not initialize" ); return; }
        wait 0.1
    }
    array<ItemDisplayData> suits = GetVisibleItemsOfType( eItemTypes.PILOT_SUIT )
    clGlobal.editingPilotLoadoutIndex = 0
    clGlobal.heldPilotWeaponType = eItemTypes.PILOT_PRIMARY
    UpdatePilotModel( player, 0 )
    for ( int attempt = 0; attempt < 3; attempt++ )
    {
        int itemIndex = attempt % suits.len()
        PreviewPilotCharacter( player, itemIndex )
        asset expected = clGlobal.previewMenuPilotModels.bodyModel
        if ( expected == $"" ) { print( "MENU_PREVIEW_PROBE: FAIL preview started empty" ); return; }
        player.ClientCommand( "SetPersistentLoadoutValue pilot 0 name PREVIEW_CHECK_" + attempt )
        wait 3.0
        if ( clGlobal.previewMenuPilotModels.bodyModel != expected )
        {
            // Do not call Save here: an empty preview is the crash condition.
            print( "MENU_PREVIEW_PROBE: FAIL background sync cleared active character preview" )
            return
        }
        SavePilotCharacterPreview( player )
        if ( clGlobal.currentMenuPilotModels.bodyModel != expected ) { print( "MENU_PREVIEW_PROBE: FAIL saved model differs" ); return; }
        player.ClientCommand( "SetPersistentLoadoutValue pilot 0 suit " + suits[ itemIndex ].ref )
        print( "MENU_PREVIEW_PROBE: PASS equip attempt=" + attempt + " suit=" + suits[ itemIndex ].ref )
        wait 1.0
    }
    print( "MENU_PREVIEW_PROBE: PASS all preview/equip cycles after match-to-lobby" )
}
