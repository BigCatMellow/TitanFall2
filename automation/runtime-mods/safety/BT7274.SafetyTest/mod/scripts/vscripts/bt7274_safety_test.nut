untyped
global function BT7274SafetyTest_Init
struct { bool started=false } file
void function BT7274SafetyTest_Init()
{
    if(!GetConVarBool("bt7274_safety_test"))return
    AddCallback_OnClientConnected(BT7274SafetyTest_Connect)
    AddCallback_GameStateEnter(eGameState.Playing,BT7274SafetyTest_Start)
    if(IsLobby())thread BT7274SafetyTest_Lobby()
}
void function BT7274SafetyTest_Connect(entity player)
{
    if(player.GetUID()!="0")player.SetPersistentVar("privateMatchState",0)
}
void function BT7274SafetyTest_Lobby()
{
    wait 6.0
    print("SAFETY_TEST_LOBBY")
    GameRules_ChangeMap("mp_lf_meadow","tdm")
}
void function BT7274SafetyTest_Start()
{
    if(file.started)return
    file.started=true
    thread BT7274SafetyTest_Run()
}
void function BT7274SafetyTest_Require(bool ok,string message)
{
    if(!ok){print("SAFETY_TEST_FAILED reason="+message);throw message}
}
void function BT7274SafetyTest_Flags(bool enabled)
{
    bool nav=GetConVarBool("bt7274_safety_navigation")
    SetConVarBool("bot_offhand_safety",enabled&&!nav)
    SetConVarBool("bot_stall_retarget",enabled&&!nav)
    if(nav)SetConVarBool("bot_corner_height_guard",enabled)
}
void function BT7274SafetyTest_Phase(string name,float duration)
{
    print("SAFETY_TEST_PHASE map="+GetMapName()+" name="+name+" t="+Time()+" safety="+GetConVarBool("bot_offhand_safety")+" retarget="+GetConVarBool("bot_stall_retarget"))
    float until=Time()+duration
    while(Time()<until){wait 5.0;print("SAFETY_TEST_HEARTBEAT phase="+name+" t="+Time()+" population="+GetPlayerArray().len())}
    BT7274SafetyTest_Require(BT7274SafetyTest_Bots().len()==16,"Bot population changed")
    BT7274SafetyTest_Require(fabs(GetConVarFloat("bot_aim_error_scale")-0.78)<0.001,"Aim changed")
    if(GetConVarBool("bt7274_safety_navigation")){
        BT7274SafetyTest_Require(!GetConVarBool("bot_offhand_safety")&&!GetConVarBool("bot_stall_retarget"),"Unrelated safety flags changed")
        print("SAFETY_TEST_NAV_STATE phase="+name+" corner="+GetConVarBool("bot_corner_height_guard"))
    }
    print("SAFETY_TEST_PHASE_PASS name="+name+" t="+Time())
}
array<entity> function BT7274SafetyTest_Bots()
{
    array<entity> bots
    foreach(entity p in GetPlayerArray())if(p.GetUID()=="0")bots.append(p)
    return bots
}
void function BT7274SafetyTest_Spectate(entity p)
{
    WaitEndFrame()
    if(!IsValid(p))return
    p.SetPersistentVar("privateMatchState",1)
    if(IsAlive(p))p.Die()
    wait 0.1
    if(!IsValid(p))return
    p.Signal("OnRespawned")
    ClearRespawnAvailable(p)
    p.SetPlayerSettings("spectator")
    p.StopPhysics()
    InitialisePrivateMatchSpectatorPlayer(p)
}
void function BT7274SafetyTest_Respawn()
{
    foreach(entity p in GetPlayerArray())if(p.GetUID()=="0"&&IsAlive(p))p.Die()
}
void function BT7274SafetyTest_Run()
{
    wait 1.0
    SetConVarInt("bot_manager_target",17)
    SetConVarInt("bot_manager_max",17)
    entity human=null
    float deadline=Time()+40.0
    while(Time()<deadline){
        foreach(entity p in GetPlayerArray())if(p.GetUID()!="0")human=p
        if(BT7274SafetyTest_Bots().len()==16)break
        wait 0.25
    }
    BT7274SafetyTest_Require(BT7274SafetyTest_Bots().len()==16,"Need16fighting bots")
    if(IsValid(human)){
        BT7274SafetyTest_Spectate(human)
        BT7274SafetyTest_Require(!IsAlive(human),"Human observer must be inactive")
    }
    int imc=0
    foreach(entity p in BT7274SafetyTest_Bots())if(p.GetTeam()==TEAM_IMC)imc++
    foreach(entity p in BT7274SafetyTest_Bots()){
        if(imc>8&&p.GetTeam()==TEAM_IMC){SetTeam(p,TEAM_MILITIA);imc--}
        else if(imc<8&&p.GetTeam()==TEAM_MILITIA){SetTeam(p,TEAM_IMC);imc++}
    }
    print("SAFETY_TEST_POPULATION bots=16 imc=8 militia=8 observer_alive=0")
    foreach(string name in ["bot_nav_diagnostics","bot_proximity_fix","bot_combat_movement","bot_height_response","bot_defensive_tactics","bot_skill_use","bot_personality","bt7274_bot_roster","bt7274_bot_tacticals"])SetConVarBool(name,true)
    foreach(string name in ["bot_route_guard","bot_jump_timing","bot_perception_fix","bot_crouch_recovery"])SetConVarBool(name,false)
    BT7274SafetyTest_Flags(false)
    BT7274SafetyTest_Respawn()
    if(GetConVarBool("bt7274_safety_navigation")){
        if(GetConVarInt("bt7274_safety_stage")==1){
            BT7274SafetyTest_Phase("nav_control",90.0)
            BT7274SafetyTest_Flags(true)
            BT7274SafetyTest_Respawn()
            BT7274SafetyTest_Phase("nav_guard",120.0)
            BT7274SafetyTest_Respawn()
            BT7274SafetyTest_Phase("nav_respawn",30.0)
            BT7274SafetyTest_Flags(false)
            BT7274SafetyTest_Respawn()
            BT7274SafetyTest_Phase("nav_disabled",10.0)
            SetConVarInt("bt7274_safety_stage",2)
            print("SAFETY_TEST_TRANSITION to=mp_lobby")
            GameRules_ChangeMap("mp_lobby","tdm")
        }else{
            BT7274SafetyTest_Flags(true)
            BT7274SafetyTest_Respawn()
            BT7274SafetyTest_Phase("nav_new_map",90.0)
            BT7274SafetyTest_Flags(false)
            print("SAFETY_TEST_DONE map="+GetMapName()+" t="+Time())
        }
        return
    }
    if(GetConVarInt("bt7274_safety_stage")==1){
        BT7274SafetyTest_Phase("v20_control",90.0)
        BT7274SafetyTest_Flags(true)
        BT7274SafetyTest_Respawn()
        BT7274SafetyTest_Phase("v21_safety",180.0)
        // Health is manipulated only in this separately marked diagnostic phase.
        print("SAFETY_TEST_ABILITY_PROBE t="+Time())
        foreach(entity p in GetPlayerArray())if(p.GetUID()=="0"&&IsAlive(p)&&!p.IsTitan()){
            p.SetInvulnerable()
            p.SetHealth(35)
        }
        BT7274SafetyTest_Phase("hurt_ability_probe",40.0)
        BT7274SafetyTest_Flags(false)
        BT7274SafetyTest_Respawn()
        BT7274SafetyTest_Phase("switch_off",10.0)
        SetConVarInt("bt7274_safety_stage",2)
        print("SAFETY_TEST_TRANSITION to=mp_lobby")
        GameRules_ChangeMap("mp_lobby","tdm")
    }else{
        BT7274SafetyTest_Flags(true)
        BT7274SafetyTest_Respawn()
        BT7274SafetyTest_Phase("new_map_safety",100.0)
        BT7274SafetyTest_Flags(false)
        print("SAFETY_TEST_DONE map="+GetMapName()+" t="+Time())
    }
}
