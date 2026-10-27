untyped
global function WeaponNotesTest_Init
void function WeaponNotesTest_Init()
{
    if(GetConVarString("solo_notes_mode")=="controlled_validation"){
        AddCallback_OnClientConnected(WeaponNotesTest_Connect)
        AddCallback_GameStateEnter(eGameState.Playing,WeaponNotesTest_Start)
    }
}
void function WeaponNotesTest_Connect(entity player){if(player.GetUID()!="0")player.SetPersistentVar("privateMatchState",0)}
void function WeaponNotesTest_Start(){thread WeaponNotesTest_Run()}
void function WeaponNotesTest_Hit(entity target,entity attacker,float amount)
{
    entity gun=attacker.GetMainWeapons()[0]
    Assert(gun.GetWeaponClassName()=="mp_weapon_rspn101","Synthetic source must match its actual weapon entity")
    target.TakeDamage(amount,attacker,gun,{damageSourceId=eDamageSourceId.mp_weapon_rspn101})
}
void function WeaponNotesTest_Run()
{
    SetConVarInt("bot_cmds_type",0)
    wait 5.0
    float deadline=Time()+30.0
    while(GetPlayerArray().len()!=16&&Time()<deadline)wait 0.25
    Assert(GetPlayerArray().len()==16,"Notes test needs human plus 15 bots")
    entity human=null
    array<entity> enemies=[]
    entity ally=null
    foreach(entity p in GetPlayerArray())if(p.GetUID()!="0")human=p
    Assert(IsValid(human)&&IsAlive(human),"No living human for notes test")
    human.SetInvulnerable()
    foreach(entity p in GetPlayerArray()){
        if(p.GetUID()!="0"||!IsAlive(p))continue
        p.ClearInvulnerable()
        p.SetHealth(100)
        if(p.GetTeam()!=human.GetTeam())enemies.append(p)
        else ally=p
    }
    Assert(enemies.len()>=4&&IsValid(ally),"Notes test population missing")
    PilotLoadoutDef loadout=GetPilotLoadoutFromPersistentData(human,0)
    loadout.primary="mp_weapon_rspn101"
    loadout.primarySkinIndex=0
    loadout.primaryCamoIndex=0
    loadout.primaryMod1=""
    loadout.primaryMod2=""
    loadout.primaryMod3=""
    loadout.primaryAttachment=""
    UpdateDerivedPilotLoadoutData(loadout)
    GivePilotLoadout(human,loadout)
    wait 0.5
    print("WNOTE_TEST_CASE name=four_hits victim="+enemies[0].GetEncodedEHandle())
    float firstHit=Time()
    float lastHit=Time()
    for(int i=0;i<4;i++){lastHit=Time();WeaponNotesTest_Hit(enemies[0],human,25.0);wait 0.1}
    print("WNOTE_TEST_TIMING expected_span="+(lastHit-firstHit))
    print("WNOTE_TEST_CASE name=mixed_attackers victim="+enemies[1].GetEncodedEHandle())
    WeaponNotesTest_Hit(enemies[1],human,50.0)
    wait 0.1
    WeaponNotesTest_Hit(enemies[1],ally,50.0)
    print("WNOTE_TEST_CASE name=injured_start victim="+enemies[2].GetEncodedEHandle())
    enemies[2].SetHealth(50)
    WeaponNotesTest_Hit(enemies[2],human,25.0)
    wait 0.1
    WeaponNotesTest_Hit(enemies[2],human,25.0)
    print("WNOTE_TEST_CASE name=healing victim="+enemies[3].GetEncodedEHandle())
    WeaponNotesTest_Hit(enemies[3],human,25.0)
    wait 0.1
    enemies[3].SetHealth(90)
    WeaponNotesTest_Hit(enemies[3],human,90.0)
    print("WNOTE_TEST_COMPLETE population="+GetPlayerArray().len())
    SetConVarInt("bot_cmds_type",6)
    human.ClearInvulnerable()
}
