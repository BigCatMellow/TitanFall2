untyped
global function BT7274MapSurvey_Init
struct {
    bool started = false
    bool counting = false
    bool finishing = false
    bool observerReady = false
    float began = 0.0
    int kills = 0
    table players
    array<string> maps = ["mp_complex3"]
} file
void function BT7274MapSurvey_Init()
{
    AddCallback_OnClientConnected( BT7274MapSurvey_Connect )
    AddCallback_OnPlayerRespawned( BT7274MapSurvey_Respawn )
    AddCallback_OnPlayerKilled( BT7274MapSurvey_Killed )
    AddCallback_GameStateEnter( eGameState.Playing, BT7274MapSurvey_Start )
    AddCallback_GameStateEnter( eGameState.WinnerDetermined, BT7274MapSurvey_Winner )
}
void function BT7274MapSurvey_Connect( entity player )
{
    if ( player.GetUID() != "0" ) player.SetPersistentVar( "privateMatchState", 0 )
}
void function BT7274MapSurvey_Respawn( entity player )
{
    if ( file.observerReady && player.GetUID() != "0" ) thread BT7274MapSurvey_Spectate( player )
}
void function BT7274MapSurvey_Spectate( entity player )
{
    WaitEndFrame()
    if ( !IsValid(player) ) return
    player.SetPersistentVar( "privateMatchState", 1 )
    if ( IsAlive(player) ) player.Die()
    wait 0.1
    if ( !IsValid(player) ) return
    // Stop the stock delayed respawn thread, using the same signal as normal respawn.
    player.Signal( "OnRespawned" )
    ClearRespawnAvailable(player)
    player.SetPlayerSettings( "spectator" )
    player.StopPhysics()
    InitialisePrivateMatchSpectatorPlayer( player )
    print( "MAP_SURVEY_OBSERVER map=" + GetMapName() + " alive=" + IsAlive(player) + " team=" + player.GetTeam() )
}
void function BT7274MapSurvey_Start()
{
    if ( file.started ) return
    file.started = true
    thread BT7274MapSurvey_Run()
}
array<entity> function BT7274MapSurvey_Bots()
{
    array<entity> bots
    foreach ( entity player in GetPlayerArray() ) if ( player.GetUID() == "0" ) bots.append(player)
    return bots
}
void function BT7274MapSurvey_Run()
{
    int index = GetConVarInt("bt7274_survey_index")
    if ( index < 0 || index >= file.maps.len() || GetMapName() != file.maps[index] )
    {
        BT7274MapSurvey_Finish("map_mismatch")
        return
    }
    // Allow a real pilot to bootstrap the existing manager, then remove the human from combat.
    float warmup = Time()
    while ( BT7274MapSurvey_Bots().len() < 1 && Time() - warmup < 25.0 ) wait 0.25
    file.observerReady = true
    foreach ( entity player in GetPlayerArray() )
        if ( player.GetUID() != "0" ) thread BT7274MapSurvey_Spectate(player)
    while ( BT7274MapSurvey_Bots().len() < 16 && Time() - warmup < 60.0 ) wait 0.25
    wait 1.0
    array<entity> bots = BT7274MapSurvey_Bots()
    if ( bots.len() != 16 ) { BT7274MapSurvey_Finish("population_timeout"); return }
    int imc = 0
    foreach ( entity bot in bots ) if ( bot.GetTeam() == TEAM_IMC ) imc++
    foreach ( entity bot in bots )
    {
        if ( imc > 8 && bot.GetTeam() == TEAM_IMC ) { SetTeam(bot,TEAM_MILITIA); imc-- }
        else if ( imc < 8 && bot.GetTeam() == TEAM_MILITIA ) { SetTeam(bot,TEAM_IMC); imc++ }
    }
    foreach ( entity player in GetPlayerArray() )
        if ( player.GetUID() != "0" && IsAlive(player) ) { BT7274MapSurvey_Finish("observer_alive"); return }
    AddTeamScore(TEAM_IMC, -GameRules_GetTeamScore(TEAM_IMC))
    AddTeamScore(TEAM_MILITIA, -GameRules_GetTeamScore(TEAM_MILITIA))
    file.kills = 0
    file.players.clear()
    file.began = Time()
    file.counting = true
    print( "MAP_SURVEY_BEGIN map=" + GetMapName() + " index=" + index + " goal=" + GetConVarInt("bt7274_survey_goal") + " engine_goal=" + GetScoreLimit_FromPlaylist() + " bots=16 imc=8 militia=8 observer_alive=0 smoke=" + GetConVarInt("bt7274_survey_smoke") )
    while ( !file.finishing )
    {
        int score2 = GameRules_GetTeamScore(TEAM_IMC)
        int score3 = GameRules_GetTeamScore(TEAM_MILITIA)
        print( "MAP_SURVEY_SCORE map=" + GetMapName() + " index=" + index + " elapsed=" + (Time()-file.began) + " imc=" + score2 + " militia=" + score3 + " kills=" + file.kills + " bots=" + BT7274MapSurvey_Bots().len() )
        NSSaveJSONFile("progress.json", {map=GetMapName(),index=index,elapsed=Time()-file.began,imc=score2,militia=score3,goal=GetConVarInt("bt7274_survey_goal")})
        if ( max(score2,score3) >= GetConVarInt("bt7274_survey_goal") ) { BT7274MapSurvey_Finish("score_limit"); return }
        if ( Time()-file.began >= GetConVarInt("bt7274_survey_minutes")*60 ) { BT7274MapSurvey_Finish("time_limit"); return }
        wait 5.0
    }
}
void function BT7274MapSurvey_Killed( entity victim, entity attacker, var damageInfo )
{
    if ( !file.counting || !victim.IsPlayer() || victim.GetUID() != "0" ) return
    bool credited = IsValid(attacker) && attacker.IsPlayer() && attacker.GetUID() == "0" && attacker != victim && attacker.GetTeam() != victim.GetTeam()
    if ( credited ) file.kills++
    string victimKey = string(victim.GetEncodedEHandle())
    if ( !(victimKey in file.players) ) file.players[victimKey] <- {name=victim.GetPlayerName(),team=victim.GetTeam(),kills=0,deaths=0}
    file.players[victimKey].deaths++
    if ( credited )
    {
        string key = string(attacker.GetEncodedEHandle())
        if ( !(key in file.players) ) file.players[key] <- {name=attacker.GetPlayerName(),team=attacker.GetTeam(),kills=0,deaths=0}
        file.players[key].kills++
    }
    print( "MAP_SURVEY_KILL map=" + GetMapName() + " t=" + Time() + " victim=" + victim.GetEncodedEHandle() + " attacker=" + (credited ? attacker.GetEncodedEHandle() : -1) + " credited=" + credited )
}
void function BT7274MapSurvey_Winner()
{
    if ( !file.started ) return
    string reason = max(GameRules_GetTeamScore(TEAM_IMC),GameRules_GetTeamScore(TEAM_MILITIA)) >= GetConVarInt("bt7274_survey_goal") ? "score_limit" : "time_limit_or_rules"
    BT7274MapSurvey_Finish(reason)
}
void function BT7274MapSurvey_Finish( string reason )
{
    if ( file.finishing ) return
    file.finishing = true
    thread BT7274MapSurvey_End(reason)
}
void function BT7274MapSurvey_End( string reason )
{
    wait 0.25
    bool valid = file.counting
    file.counting = false
    int index = GetConVarInt("bt7274_survey_index")
    int score2 = GameRules_GetTeamScore(TEAM_IMC)
    int score3 = GameRules_GetTeamScore(TEAM_MILITIA)
    float elapsed = valid ? Time()-file.began : 0.0
    table result = {map=GetMapName(),index=index,goal=GetConVarInt("bt7274_survey_goal"),imc=score2,militia=score3,elapsed=elapsed,reason=reason,valid=valid,smoke=GetConVarInt("bt7274_survey_smoke"),kills=file.kills,players=file.players}
    NSSaveJSONFile("result_"+index+"_"+GetMapName()+".json",result)
    print( "MAP_SURVEY_RESULT map=" + GetMapName() + " index=" + index + " imc=" + score2 + " militia=" + score3 + " elapsed=" + elapsed + " reason=" + reason + " valid=" + valid )
    wait 2.0
    if ( index+1 >= min(GetConVarInt("bt7274_survey_count"),file.maps.len()) )
    {
        print( "MAP_SURVEY_DONE maps=" + (index+1) + " smoke=" + GetConVarInt("bt7274_survey_smoke") )
        wait 3.0
        ServerCommand("quit")
    }
    else
    {
        SetConVarInt("bt7274_survey_index",index+1)
        GameRules_ChangeMap(file.maps[index+1],"tdm")
    }
}
