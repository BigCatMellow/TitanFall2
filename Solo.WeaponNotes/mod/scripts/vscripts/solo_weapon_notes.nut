untyped
global function WeaponNotes_Init
struct {
    table lives
    table pending
    table last
    int serial = 0
    int errors = 0
    bool context = false
} file
void function WeaponNotes_Init()
{
    AddDamageFinalCallback("player",WeaponNotes_Pre)
    AddCallback_OnPlayerKilled(WeaponNotes_Killed)
    AddCallback_OnPlayerRespawned(WeaponNotes_Respawn)
    AddCallback_GameStateEnter(eGameState.Playing,WeaponNotes_Context)
}
bool function WeaponNotes_Enabled()
{
    return file.errors<3 && GetConVarBool("solo_weapon_notes") && GetConVarBool("ns_auth_allow_insecure") && !IsLobby()
}
string function WeaponNotes_Kind(entity player)
{
    if(!IsValid(player))return "world"
    if(!player.IsPlayer())return "other"
    return player.GetUID()=="0" ? "bot" : "human"
}
int function WeaponNotes_Life(entity player)
{
    if(!IsValid(player))return 0
    int id=player.GetEncodedEHandle()
    if(!(id in file.lives))file.lives[id]<-1
    return expect int(file.lives[id])
}
string function WeaponNotes_Config()
{
    return string(GetConVarBool("james_ads_trial"))+":"+string(GetConVarBool("solo_weapon_balance"))+":"
        +string(GetConVarBool("solo_weapon_balance_bots"))+":"+string(GetConVarBool("james_weapon_reload"))+":"+string(GetConVarBool("james_tactical_recharge"))
}
void function WeaponNotes_Context()
{
    if(!WeaponNotes_Enabled())return
    file.context=true
    print("WNOTE_CONTEXT schema=1 map="+GetMapName()+" mode="+GetConVarString("solo_notes_mode")+" config="+WeaponNotes_Config()+" tick="+GetConVarFloat("base_tickinterval_mp"))
}
void function WeaponNotes_Respawn(entity player)
{
    int id=player.GetEncodedEHandle()
    if(!(id in file.lives))file.lives[id]<-0
    file.lives[id]++
    if(id in file.pending)delete file.pending[id]
    if(id in file.last)delete file.last[id]
    if(WeaponNotes_Enabled())print("WNOTE_LIFE t="+Time()+" victim="+id+" life="+file.lives[id]+" kind="+WeaponNotes_Kind(player))
}
void function WeaponNotes_Error(string stage,var error)
{
    file.errors++
    print("WNOTE_ERROR stage="+stage+" count="+file.errors)
    print(string(error)) // General private game log only; the collector ignores it.
}
void function WeaponNotes_Pre(entity victim,var info)
{
    if(!WeaponNotes_Enabled()||!IsValid(victim)||victim.IsTitan()||victim.GetHealth()<=0)return
    try{
        if(!file.context)WeaponNotes_Context()
        float damage=DamageInfo_GetDamage(info)
        if(damage<=0.0)return
        entity attacker=DamageInfo_GetAttacker(info)
        entity weapon=DamageInfo_GetWeapon(info)
        var damageName=DamageInfo_GetDamageWeaponName(info)
        string gun=typeof damageName=="string" ? expect string(damageName) : ""
        int source=DamageInfo_GetDamageSourceIdentifier(info)
        if(gun.len()==0&&DamageSourceIDHasString(source))gun=DamageSourceIDToString(source)
        if(gun.len()==0||gun.find(" ")!=null)gun="unknown"
        if(!IsValid(weapon)){
            entity inflictor=DamageInfo_GetInflictor(info)
            if(IsValid(inflictor)&&inflictor.GetClassName().find("mp_weapon_")==0)weapon=inflictor
        }
        string mods="unknown"
        if(IsValid(weapon)&&weapon.GetWeaponClassName()==gun){
            mods="none"
            foreach(string mod in weapon.GetMods())mods=(mods=="none"?mod:mods+","+mod)
        }
        int id=victim.GetEncodedEHandle()
        if(id in file.pending)print("WNOTE_GAP event="+file.pending[id]+" victim="+id+" life="+WeaponNotes_Life(victim))
        int serial=++file.serial
        file.pending[id]<-serial
        file.last[id]<-{event=serial,t=Time()}
        vector av=IsValid(attacker)?attacker.GetVelocity():<0,0,0>
        vector vv=victim.GetVelocity()
        print("WNOTE_HIT event="+serial+" t="+Time()+" victim="+id+" life="+WeaponNotes_Life(victim)
            +" attacker="+(IsValid(attacker)?attacker.GetEncodedEHandle():-1)+" attacker_life="+WeaponNotes_Life(attacker)
            +" akind="+WeaponNotes_Kind(attacker)+" vkind="+WeaponNotes_Kind(victim)
            +" atitan="+(IsValid(attacker)&&attacker.IsPlayer()?attacker.IsTitan():false)
            +" ateam="+(IsValid(attacker)&&attacker.IsPlayer()?attacker.GetTeam():0)+" vteam="+victim.GetTeam()
            +" gun="+gun+" source="+source+" mods="+mods+" config="+WeaponNotes_Config()
            +" hp="+victim.GetHealth()+" max_hp="+victim.GetMaxHealth()+" reported_damage="+damage
            +" hitgroup="+DamageInfo_GetHitGroup(info)+" crit_scale="+DamageInfo_GetDamageCriticalHitScale(info)
            +" force="+DamageInfo_GetForceKill(info)+" range="+DamageInfo_GetDistFromAttackOrigin(info)
            +" avx="+av.x+" avy="+av.y+" avz="+av.z+" vvx="+vv.x+" vvy="+vv.y+" vvz="+vv.z)
        thread WeaponNotes_AfterFrame(victim,serial,WeaponNotes_Life(victim))
    }catch(error){WeaponNotes_Error("pre",error)}
}
void function WeaponNotes_FinishHit(entity victim,bool killed)
{
    int id=victim.GetEncodedEHandle()
    if(!(id in file.pending))return
    float hp=killed?0.0:(victim.GetHealth()>0?victim.GetHealth().tofloat():0.0)
    print("WNOTE_POST event="+file.pending[id]+" victim="+id+" life="+WeaponNotes_Life(victim)+" t="+Time()+" hp_after="+hp)
    delete file.pending[id]
}
void function WeaponNotes_AfterFrame(entity victim,int event,int life)
{
    // AddPostDamageCallback still sees pre-deduction HP in this runtime.
    // Read after the engine applies damage. Concurrent hits invalidate the
    // overwritten record instead of pretending that a frame total is one hit.
    WaitEndFrame()
    if(!WeaponNotes_Enabled()||!IsValid(victim)||victim.IsTitan())return
    int id=victim.GetEncodedEHandle()
    if(WeaponNotes_Life(victim)!=life||!(id in file.pending)||file.pending[id]!=event)return
    try{WeaponNotes_FinishHit(victim,!IsAlive(victim))}catch(error){WeaponNotes_Error("post",error)}
}
void function WeaponNotes_Killed(entity victim,entity attacker,var info)
{
    if(!WeaponNotes_Enabled()||!IsValid(victim)||victim.IsTitan())return
    try{
        WeaponNotes_FinishHit(victim,true)
        int id=victim.GetEncodedEHandle()
        int event=0
        if(id in file.last&&fabs(Time()-file.last[id].t)<0.05)event=expect int(file.last[id].event)
        print("WNOTE_DEATH t="+Time()+" victim="+id+" life="+WeaponNotes_Life(victim)+" event="+event)
    }catch(error){WeaponNotes_Error("death",error)}
}
