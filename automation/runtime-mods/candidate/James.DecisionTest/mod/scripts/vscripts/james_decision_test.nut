untyped
global function JamesDecisionTest_Init
struct {
    bool started = false
    bool observing = false
} file

void function JamesDecisionTest_Init()
{
    int phase = GetConVarInt( "james_candidate_phase" )
    bool dedicated = GetConVarBool("james_candidate_dedicated")
    if ( dedicated )
    {
        SetConVarBool("bot_manager_enabled",false)
        thread JamesDecisionTest_DedicatedSpawn()
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
    AddCallback_OnClientConnected( JamesDecisionTest_Connect )
    AddCallback_OnPlayerRespawned( JamesDecisionTest_Respawn )
    AddCallback_GameStateEnter( eGameState.Playing, JamesDecisionTest_Start )
    if ( IsLobby() ) thread JamesDecisionTest_Lobby()
}
void function JamesDecisionTest_DedicatedSpawn()
{
    wait 3.0
    for ( int i=0; i<16; i++ )
    {
        BotSpawn("TestBot"+i)
        wait 0.5
    }
}
void function JamesDecisionTest_Connect( entity player )
{
    if ( GetConVarInt("james_candidate_phase") == 6 && player.GetUID() != "0" )
        player.SetPersistentVar("privateMatchState",0)
}
void function JamesDecisionTest_Lobby()
{
    wait 12.0
    print( "DECISION_TEST_LOBBY: phase=" + GetConVarInt("james_candidate_phase") + " map=" + GetMapName() )
    SetConVarInt( "james_candidate_phase", 6 )
    GameRules_ChangeMap( "mp_eden", "tdm" )
}
void function JamesDecisionTest_Respawn( entity player )
{
    if ( player.GetUID() != "0" )
    {
        if ( file.observing ) thread JamesDecisionTest_Observe( player )
        return
    }
    if ( GetConVarInt("james_candidate_phase") >= 2 && GetConVarInt("james_candidate_phase") <= 4 ) thread JamesDecisionTest_Loadout( player )
}
void function JamesDecisionTest_Loadout( entity bot )
{
    WaitEndFrame()
    if ( !IsValid(bot) || !IsAlive(bot) || bot.IsTitan() ) return
    PilotLoadoutDef loadout = GetPilotLoadoutFromPersistentData( bot, 0 )
    array<string> suits = ["nomad","light","geist","medium","stalker","heavy","grapple"]
    array<string> guns = ["mp_weapon_rspn101","mp_weapon_car","mp_weapon_shotgun","mp_weapon_g2","mp_weapon_epg","mp_weapon_lstar"]
    int slot = bot.GetEntIndex()
    loadout.suit = suits[slot % suits.len()]
    if ( GetConVarInt("james_candidate_phase") == 4 ) loadout.primary = guns[slot % guns.len()]
    loadout.primarySkinIndex = 0
    loadout.primaryCamoIndex = 0
    loadout.primaryMod1 = ""
    loadout.primaryMod2 = ""
    loadout.primaryMod3 = ""
    loadout.primaryAttachment = ""
    UpdateDerivedPilotLoadoutData( loadout )
    GivePilotLoadout( bot, loadout )
    print( "DECISION_TEST_LOADOUT map=" + GetMapName() + " phase=" + GetConVarInt("james_candidate_phase")
        + " entity_index=" + slot + " primary=" + loadout.primary + " suit=" + loadout.suit )
}
void function JamesDecisionTest_Observe( entity player )
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
void function JamesDecisionTest_Start()
{
    if ( file.started ) return
    file.started = true
    thread JamesDecisionTest_Run()
}
void function JamesDecisionTest_Run()
{
    int phase = GetConVarInt("james_candidate_phase")
    bool dedicated = GetConVarBool("james_candidate_dedicated")
    float warmup = Time()
    while ( GetPlayerArray().len() < 2 && Time() - warmup < 30.0 ) wait 0.25
    file.observing = !dedicated && phase != 6
    if ( file.observing )
        foreach ( entity p in GetPlayerArray() )
            if ( p.GetUID() != "0" ) thread JamesDecisionTest_Observe(p)
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
    if ( GetConVarBool("james_candidate_quick") ) duration = 60.0
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
        SetConVarInt("james_candidate_phase",6)
        GameRules_ChangeMap("mp_eden","tdm")
        return
    }
    array<string> nextMaps = ["mp_eden","mp_eden","mp_complex3","mp_black_water_canal","mp_lobby"]
    Assert( phase >= 0 && phase < nextMaps.len(), "Unexpected candidate phase" )
    SetConVarInt( "james_candidate_phase", phase + 1 )
    GameRules_ChangeMap( nextMaps[phase], "tdm" )
}
