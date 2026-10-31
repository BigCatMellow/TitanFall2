untyped
global function BT7274FragSelfTest_Init
struct { bool started=false } file
void function BT7274FragSelfTest_Init()
{
    if(!GetConVarBool("bt7274_frag_self_test"))return
    AddCallback_OnClientConnected(BT7274FragSelfTest_Connect)
    AddCallback_GameStateEnter(eGameState.Playing,BT7274FragSelfTest_Start)
    if(IsLobby())thread BT7274FragSelfTest_Lobby()
}
void function BT7274FragSelfTest_Connect(entity p){if(p.GetUID()!="0")p.SetPersistentVar("privateMatchState",0)}
void function BT7274FragSelfTest_Require(bool ok,string reason)
{
    if(!ok){print("FRAG_SELF_TEST_FAILED reason="+reason);throw reason}
}
void function BT7274FragSelfTest_Lobby(){wait 4.0;print("FRAG_SELF_TEST_LOBBY");GameRules_ChangeMap("mp_glitch","tdm")}
void function BT7274FragSelfTest_Start(){if(file.started)return;file.started=true;thread BT7274FragSelfTest_Run()}
void function BT7274FragSelfTest_Case(string name,entity target,entity attacker,int source,int expected,bool enabled=true,float scale=0.25)
{
    BT7274FragSelfTest_Require(IsAlive(target)&&IsAlive(attacker),"matrix actors not alive")
    SetConVarBool("bt7274_bot_frag_self_damage",enabled)
    SetConVarFloat("bt7274_bot_frag_self_damage_scale",scale)
    target.ClearInvulnerable()
    target.SetHealth(100)
    target.TakeDamage(40.0,attacker,attacker,{damageSourceId=source})
    WaitEndFrame()
    int after=target.GetHealth()
    print("FRAG_SELF_TEST_CASE map="+GetMapName()+" name="+name+" expected="+expected+" hp="+after)
    BT7274FragSelfTest_Require(after==expected,"damage matrix mismatch "+name)
    target.SetInvulnerable()
}
void function BT7274FragSelfTest_Matrix(entity human,entity bot,entity enemy,entity ally,string phase)
{
    print("FRAG_SELF_TEST_PHASE name="+phase+" map="+GetMapName())
    int frag=eDamageSourceId.mp_weapon_frag_grenade
    BT7274FragSelfTest_Case("bot_self_quarter",bot,bot,frag,90)
    BT7274FragSelfTest_Case("bot_self_disabled",bot,bot,frag,60,false)
    BT7274FragSelfTest_Case("bot_self_full",bot,bot,frag,60,true,1.0)
    BT7274FragSelfTest_Case("bot_self_immune",bot,bot,frag,100,true,0.0)
    BT7274FragSelfTest_Case("bot_self_invalid_negative",bot,bot,frag,60,true,-1.0)
    BT7274FragSelfTest_Case("bot_self_invalid_high",bot,bot,frag,60,true,2.0)
    BT7274FragSelfTest_Case("human_self",human,human,frag,60)
    BT7274FragSelfTest_Case("bot_to_enemy",enemy,bot,frag,60)
    BT7274FragSelfTest_Case("bot_to_human",human,enemy,frag,60)
    BT7274FragSelfTest_Case("human_to_bot",enemy,human,frag,60)
    // Friendly fire normally filters damage. The scaler must not change that.
    BT7274FragSelfTest_Case("bot_to_ally",ally,bot,frag,100)
    BT7274FragSelfTest_Case("bot_self_bullet",bot,bot,eDamageSourceId.mp_weapon_rspn101,60)
    BT7274FragSelfTest_Case("bot_self_arc",bot,bot,eDamageSourceId.mp_weapon_grenade_emp,60)
    SetConVarBool("bt7274_bot_frag_self_damage",true)
    SetConVarFloat("bt7274_bot_frag_self_damage_scale",0.25)
    print("FRAG_SELF_TEST_MATRIX_PASS name="+phase)
}
void function BT7274FragSelfTest_Run()
{
    SetConVarInt("bot_cmds_type",0)
    SetConVarInt("bot_manager_target",16)
    SetConVarInt("bot_manager_max",16)
    entity human=null
    entity bot=null
    entity enemy=null
    entity ally=null
    float deadline=Time()+45.0
    while(Time()<deadline){
        foreach(entity p in GetPlayerArray())if(p.GetUID()!="0"&&IsAlive(p))human=p
        if(IsValid(human)&&GetPlayerArray().len()==16)break
        wait 0.25
    }
    BT7274FragSelfTest_Require(IsValid(human)&&GetPlayerArray().len()==16,"need human plus15bots")
    foreach(entity p in GetPlayerArray()){
        if(!IsAlive(p))continue
        p.SetInvulnerable()
        if(p.GetUID()=="0"&&p.GetTeam()==human.GetTeam())bot=p
        if(p.GetUID()=="0"&&p.GetTeam()!=human.GetTeam())enemy=p
    }
    BT7274FragSelfTest_Require(IsValid(bot)&&IsValid(enemy),"missing teams")
    foreach(entity p in GetPlayerArray())if(p.GetUID()=="0"&&p!=bot&&p.GetTeam()==bot.GetTeam()&&IsAlive(p))ally=p
    BT7274FragSelfTest_Require(IsValid(ally),"missing ally")
    BT7274FragSelfTest_Matrix(human,bot,enemy,ally,"initial")
    bot.ClearInvulnerable()
    bot.Die()
    deadline=Time()+25.0
    while(!IsAlive(bot)&&Time()<deadline)wait 0.25
    BT7274FragSelfTest_Require(IsAlive(bot),"bot did not respawn")
    bot.SetInvulnerable()
    BT7274FragSelfTest_Matrix(human,bot,enemy,ally,"respawn")
    foreach(entity p in GetPlayerArray())p.ClearInvulnerable()
    SetConVarInt("bot_cmds_type",6)
    if(IsAlive(human))human.SetInvulnerable()
    print("FRAG_SELF_TEST_COMBAT_START map="+GetMapName())
    wait 45.0
    BT7274FragSelfTest_Require(fabs(GetConVarFloat("bot_aim_error_scale")-0.78)<0.001,"aim changed")
    print("FRAG_SELF_TEST_COMBAT_PASS map="+GetMapName())
    if(GetConVarInt("bt7274_frag_self_test_stage")==1){
        SetConVarInt("bt7274_frag_self_test_stage",2)
        GameRules_ChangeMap("mp_lobby","tdm")
    }else print("FRAG_SELF_TEST_DONE")
}
