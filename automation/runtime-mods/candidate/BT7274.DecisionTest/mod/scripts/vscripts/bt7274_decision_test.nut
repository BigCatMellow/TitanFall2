untyped
global function BT7274DecisionTest_Init
struct {
    bool started = false
    bool observing = false
} file

void function BT7274DecisionTest_Init()
{
    int phase = GetConVarInt( "bt7274_candidate_phase" )
    bool dedicated = GetConVarBool("bt7274_candidate_dedicated")
    if ( dedicated )
    {
        SetConVarBool("bot_manager_enabled",false)
        thread BT7274DecisionTest_DedicatedSpawn()
    }
    SetConVarBool( "bot_navigation_context", phase >= 1 )
    SetConVarBool( "bot_target_eligibility", phase >= 1 )
    SetConVarBool( "bot_action_policy", phase >= 2 )
    SetConVarBool( "bot_step_retry", phase >= 3 )
    if ( phase == 6 )
    {
        SetConVarInt("bot_manager_target",16)
        SetConVarInt("bot_manager_max",16)
    }
    AddCallback_OnClientConnected( BT7274DecisionTest_Connect )
    AddCallback_OnPlayerRespawned( BT7274DecisionTest_Respawn )
    AddCallback_GameStateEnter( eGameState.Playing, BT7274DecisionTest_Start )
    if ( IsLobby() ) thread BT7274DecisionTest_Lobby()
}
void function BT7274DecisionTest_DedicatedSpawn()
{
    wait 3.0
    for ( int i=0; i<16; i++ )
    {
        BotSpawn("TestBot"+i)
        wait 0.5
    }
}
void function BT7274DecisionTest_Connect( entity player )
{
    if ( GetConVarInt("bt7274_candidate_phase") == 6 && player.GetUID() != "0" )
        player.SetPersistentVar("privateMatchState",0)
}
void function BT7274DecisionTest_Lobby()
{
    wait 12.0
    print( "DECISION_TEST_LOBBY: phase=" + GetConVarInt("bt7274_candidate_phase") + " map=" + GetMapName() )
    SetConVarInt( "bt7274_candidate_phase", 6 )
    GameRules_ChangeMap( "mp_eden", "tdm" )
}
void function BT7274DecisionTest_Respawn( entity player )
{
    if ( player.GetUID() != "0" )
    {
        if ( file.observing ) thread BT7274DecisionTest_Observe( player )
        return
    }
    if ( GetConVarInt("bt7274_candidate_phase") >= 2 && GetConVarInt("bt7274_candidate_phase") <= 4 ) thread BT7274DecisionTest_Loadout( player )
}
void function BT7274DecisionTest_Loadout( entity bot )
{
    WaitEndFrame()
    if ( !IsValid(bot) || !IsAlive(bot) || bot.IsTitan() ) return
    PilotLoadoutDef loadout = GetPilotLoadoutFromPersistentData( bot, 0 )
    array<string> suits = ["nomad","light","geist","medium","stalker","heavy","grapple"]
    array<string> guns = ["mp_weapon_rspn101","mp_weapon_car","mp_weapon_shotgun","mp_weapon_g2","mp_weapon_epg","mp_weapon_lstar"]
    if ( GetConVarBool("bt7274_candidate_weapons") )
        guns.extend(["mp_weapon_alternator_smg","mp_weapon_mastiff","mp_weapon_esaw","mp_weapon_wingman","mp_weapon_semipistol"])
    int slot = bot.GetEntIndex()
    loadout.suit = suits[slot % suits.len()]
    if ( GetConVarInt("bt7274_candidate_phase") == 4 ) loadout.primary = guns[slot % guns.len()]
    loadout.primarySkinIndex = 0
    loadout.primaryCamoIndex = 0
    loadout.primaryMod1 = ""
    loadout.primaryMod2 = ""
    loadout.primaryMod3 = ""
    loadout.primaryAttachment = ""
    UpdateDerivedPilotLoadoutData( loadout )
    GivePilotLoadout( bot, loadout )
    print( "DECISION_TEST_LOADOUT map=" + GetMapName() + " phase=" + GetConVarInt("bt7274_candidate_phase")
        + " entity_index=" + slot + " primary=" + loadout.primary + " suit=" + loadout.suit )
}
void function BT7274DecisionTest_Observe( entity player )
{
    WaitEndFrame()
    if ( !IsValid(player) ) return
    player.SetPersistentVar( "privateMatchState", 1 )
    if ( IsAlive(player) ) player.Die()
    wait 0.1
    if ( !IsValid(player) ) return
    player.Signal( "OnRespawned" )
    ClearRespawnAvailable(player)
    player.SetPlayerSettings( "spectator" )
    player.StopPhysics()
    InitialisePrivateMatchSpectatorPlayer(player)
}
void function BT7274DecisionTest_Start()
{
    if ( file.started ) return
    file.started = true
    thread BT7274DecisionTest_Run()
}
void function BT7274DecisionTest_Run()
{
    int phase = GetConVarInt("bt7274_candidate_phase")
    bool dedicated = GetConVarBool("bt7274_candidate_dedicated")
    float warmup = Time()
    while ( GetPlayerArray().len() < 2 && Time() - warmup < 30.0 ) wait 0.25
    file.observing = !dedicated && phase != 6
    if ( file.observing )
        foreach ( entity p in GetPlayerArray() )
            if ( p.GetUID() != "0" ) thread BT7274DecisionTest_Observe(p)
    int expectedPlayers = dedicated || phase == 6 ? 16 : 17
    while ( GetPlayerArray().len() < expectedPlayers && Time() - warmup < 60.0 ) wait 0.25
    array<entity> bots
    foreach ( entity p in GetPlayerArray() ) if ( p.GetUID() == "0" ) bots.append(p)
    Assert( bots.len() == (phase == 6 && !dedicated ? 15 : 16), "Candidate bot population mismatch" )
    int imc = 0
    foreach ( entity bot in bots ) if ( bot.GetTeam() == TEAM_IMC ) imc++
    foreach ( entity bot in bots )
    {
        if ( dedicated || phase != 6 )
        {
            if ( imc > 8 && bot.GetTeam() == TEAM_IMC ) { SetTeam(bot, TEAM_MILITIA); imc-- }
            else if ( imc < 8 && bot.GetTeam() == TEAM_MILITIA ) { SetTeam(bot, TEAM_IMC); imc++ }
        }
    }
    print( "DECISION_TEST_BEGIN map=" + GetMapName() + " phase=" + phase + " bots=" + bots.len() + " imc=" + imc )
    float began = Time()
    float duration = phase == 0 || phase == 6 ? 90.0 : 150.0
    if ( GetConVarBool("bt7274_candidate_quick") ) duration = 60.0
    if ( GetConVarBool("bt7274_candidate_weapons") ) duration = 120.0
    while ( Time() - began < duration )
    {
        print( "DECISION_TEST_HEARTBEAT map=" + GetMapName() + " phase=" + phase + " elapsed=" + (Time()-began)
            + " imc=" + GameRules_GetTeamScore(TEAM_IMC) + " militia=" + GameRules_GetTeamScore(TEAM_MILITIA) )
        wait 10.0
    }
    print( "DECISION_TEST_PHASE_PASS map=" + GetMapName() + " phase=" + phase )
    if ( phase == 6 ) { print("DECISION_TEST_DONE: transitions, lobby return and staged decisions completed"); return }
    if ( dedicated && phase == 4 )
    {
        print("DECISION_TEST_COVERAGE: dedicated server; client lobby/15bot-human phase not exercised")
        SetConVarInt("bt7274_candidate_phase",6)
        GameRules_ChangeMap("mp_eden","tdm")
        return
    }
    array<string> nextMaps = ["mp_eden","mp_eden","mp_complex3","mp_black_water_canal","mp_lobby"]
    Assert( phase >= 0 && phase < nextMaps.len(), "Unexpected candidate phase" )
    SetConVarInt( "bt7274_candidate_phase", phase + 1 )
    GameRules_ChangeMap( nextMaps[phase], "tdm" )
}
