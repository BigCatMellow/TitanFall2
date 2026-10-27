untyped
global function BT7274CapabilityTest_Init
struct {
    bool started = false
    bool cancel = false
    int cancelTarget = -1
} file
void function BT7274CapabilityTest_Init()
{
    if(!GetConVarBool("bt7274_capability_test"))return
    AddCallback_OnClientConnected(BT7274CapabilityTest_Connect)
    AddCallback_OnPlayerRespawned(BT7274CapabilityTest_Respawn)
    AddCallback_GameStateEnter(eGameState.Playing,BT7274CapabilityTest_Start)
    if(IsLobby())thread BT7274CapabilityTest_Lobby()
}
void function BT7274CapabilityTest_Connect(entity p)
{
    if(p.GetUID()!="0")p.SetPersistentVar("privateMatchState",0)
}
void function BT7274CapabilityTest_Lobby()
{
    wait 6.0
    print("CAPABILITY_TEST_LOBBY stage="+GetConVarInt("bt7274_capability_stage"))
    GameRules_ChangeMap("mp_lf_meadow","tdm")
}
void function BT7274CapabilityTest_Start()
{
    if(file.started)return
    file.started=true
    thread BT7274CapabilityTest_Run()
}
void function BT7274CapabilityTest_Respawn(entity p)
{
    if(file.cancel&&p.GetEncodedEHandle()==file.cancelTarget)thread BT7274CapabilityTest_Cancel(p)
}
void function BT7274CapabilityTest_Cancel(entity p)
{
    WaitEndFrame()
    SetConVarBool("bt7274_bot_roster",false)
    SetConVarBool("bt7274_bot_tacticals",false)
    file.cancel=false
    print("CAPABILITY_TEST_CANCEL slot="+p.GetEntIndex())
}
array<string> function BT7274CapabilityTest_Flags()
{
    return ["bot_route_guard","bot_jump_timing","bot_proximity_fix","bot_perception_fix",
        "bot_combat_movement","bot_crouch_recovery","bot_height_response","bot_defensive_tactics",
        "bot_skill_use","bot_personality","bt7274_bot_roster","bt7274_bot_tacticals"]
}
void function BT7274CapabilityTest_Reset()
{
    foreach(string name in BT7274CapabilityTest_Flags())SetConVarBool(name,false)
    SetConVarBool("bot_nav_diagnostics",true)
    SetConVarBool("solo_weapon_notes_fire",true)
    SetConVarBool("solo_weapon_notes_viewkick",false)
}
void function BT7274CapabilityTest_Phase(string name,float duration)
{
    print("CAPABILITY_TEST_PHASE map="+GetMapName()+" name="+name+" t="+Time()+" aim="+GetConVarFloat("bot_aim_error_scale"))
    float until=Time()+duration
    while(Time()<until){wait 5.0;print("CAPABILITY_TEST_HEARTBEAT phase="+name+" t="+Time()+" population="+GetPlayerArray().len())}
    print("CAPABILITY_TEST_PHASE_PASS name="+name+" t="+Time())
}
void function BT7274CapabilityTest_RespawnBots()
{
    foreach(entity p in GetPlayerArray())if(p.GetUID()=="0"&&IsAlive(p))p.Die()
}
void function BT7274CapabilityTest_Run()
{
    wait 1.0
    entity human=null
    float deadline=Time()+40.0
    while(Time()<deadline){
        foreach(entity p in GetPlayerArray())if(p.GetUID()!="0"&&IsAlive(p))human=p
        if(IsValid(human)&&GetPlayerArray().len()==16)break
        wait 0.25
    }
    BT7274CapabilityTest_Require(IsValid(human)&&GetPlayerArray().len()==16,"Capability test requires human plus15bots")
    human.SetInvulnerable()
    foreach(entity p in GetPlayerArray())if(p.GetUID()=="0"){
        PilotLoadoutDef a=GetPilotLoadoutFromPersistentData(p,0)
        PilotLoadoutDef b=GetPilotLoadoutFromPersistentData(p,0)
        string primary=a.primary
        string suit=a.suit
        b.primary="mp_weapon_r97"
        b.suit="nomad"
        BT7274CapabilityTest_Require(a.primary==primary&&a.suit==suit,"Loadout snapshots are aliased")
        print("CAPABILITY_TEST_LOADOUT_COPIES independent=true")
        break
    }
    BT7274CapabilityTest_Reset()
    print("CAPABILITY_TEST_BEGIN stage="+GetConVarInt("bt7274_capability_stage")+" map="+GetMapName()+" population=16")
    if(GetConVarInt("bt7274_capability_stage")==1){
        entity weapon=human.GetActiveWeapon()
        if(IsValid(weapon)&&weapon.GetWeaponPrimaryClipCount()>=6){
            print("CAPABILITY_TEST_AMMO simulated=1 gun="+weapon.GetWeaponClassName())
            weapon.SetWeaponPrimaryClipCount(weapon.GetWeaponPrimaryClipCount()-2)
            wait 0.25
            weapon.SetWeaponPrimaryClipCount(weapon.GetWeaponPrimaryClipCount()-2)
        }
        BT7274CapabilityTest_Phase("diagnostics_only",35.0)
        SetConVarBool("bot_combat_movement",true)
        SetConVarBool("bot_proximity_fix",true)
        BT7274CapabilityTest_Phase("movement_proximity",40.0)
        // Roster changes apply to respawns, never the human's saved loadouts.
        SetConVarBool("bt7274_bot_roster",true)
        SetConVarBool("bt7274_bot_tacticals",true)
        BT7274CapabilityTest_RespawnBots()
        BT7274CapabilityTest_Phase("roster_readback",25.0)
        SetConVarBool("bot_skill_use",true)
        SetConVarBool("bot_defensive_tactics",true)
        SetConVarBool("bot_personality",true)
        SetConVarBool("bot_height_response",true)
        BT7274CapabilityTest_Phase("skills_personality_height_smoke",50.0)
        // Explicit switch-off and respawn/lobby lifecycle, followed by a new map.
        BT7274CapabilityTest_Reset()
        BT7274CapabilityTest_RespawnBots()
        BT7274CapabilityTest_Phase("switch_off_respawn",15.0)
        SetConVarInt("bt7274_capability_stage",2)
        print("CAPABILITY_TEST_TRANSITION to=mp_lobby")
        GameRules_ChangeMap("mp_lobby","tdm")
    }else{
        SetConVarBool("bot_combat_movement",true)
        SetConVarBool("bot_proximity_fix",true)
        BT7274CapabilityTest_Phase("new_map_movement",25.0)
        BT7274CapabilityTest_Reset()
        SetConVarInt("bot_cmds_type",0)
        entity probe=null
        foreach(entity p in GetPlayerArray())if(p.GetUID()=="0"&&IsAlive(p)&&!p.IsTitan()){probe=p;break}
        BT7274CapabilityTest_Require(IsValid(probe),"No living pilot for roster cancellation")
        string primary=probe.GetMainWeapons()[0].GetWeaponClassName()
        string tactical=probe.GetOffhandWeapon(OFFHAND_LEFT).GetWeaponClassName()
        file.cancelTarget=probe.GetEncodedEHandle()
        file.cancel=true
        SetConVarBool("bt7274_bot_roster",true)
        SetConVarBool("bt7274_bot_tacticals",true)
        print("CAPABILITY_TEST_PHASE map="+GetMapName()+" name=roster_cancel t="+Time())
        probe.Die()
        wait 15.0
        BT7274CapabilityTest_Require(!file.cancel&&IsAlive(probe),"Cancellation probe did not respawn")
        BT7274CapabilityTest_Require(probe.GetMainWeapons()[0].GetWeaponClassName()==primary,"Roster cancellation lost baseline primary")
        BT7274CapabilityTest_Require(probe.GetOffhandWeapon(OFFHAND_LEFT).GetWeaponClassName()==tactical,"Roster cancellation lost baseline tactical")
        print("CAPABILITY_TEST_PHASE_PASS name=roster_cancel t="+Time())
        SetConVarInt("bot_cmds_type",6)
        print("CAPABILITY_TEST_DONE map="+GetMapName()+" population="+GetPlayerArray().len())
    }
}

void function BT7274CapabilityTest_Require(bool condition,string message)
{
    if(!condition)throw message
}
