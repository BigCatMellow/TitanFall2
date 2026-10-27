untyped
global function WeaponNotes_Init
struct {
    table lives
    table pending
    table last
    int serial = 0
    int errors = 0
    bool context = false
    int fireErrors = 0
    bool zoomOk = true
} file
void function WeaponNotes_Init()
{
    AddDamageFinalCallback("player",WeaponNotes_Pre)
    AddCallback_OnPlayerKilled(WeaponNotes_Killed)
    AddCallback_OnPlayerRespawned(WeaponNotes_Respawn)
    AddCallback_GameStateEnter(eGameState.Playing,WeaponNotes_Context)
    AddCallback_OnPlayerRespawned(WeaponNotes_FireStart)
}
// Rounds-fired sampling is a separate opt-in with its own error budget, so a
// failure here can never disable the established damage/death notebook.
bool function WeaponNotes_FireEnabled()
{
    return file.fireErrors<3 && WeaponNotes_Enabled() && GetConVarBool("solo_weapon_notes_fire")
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

string function WeaponNotes_Mods(entity weapon)
{
    string mods="none"
    foreach(string mod in weapon.GetMods())mods=(mods=="none"?mod:mods+","+mod)
    return mods
}
void function WeaponNotes_FireStart(entity player)
{
    if(!WeaponNotes_FireEnabled()||!IsValid(player)||player.GetUID()=="0"||!NSIsPlayerLocalPlayer(player))return
    thread WeaponNotes_FireSampler(player,WeaponNotes_Life(player))
}
void function WeaponNotes_FireFlush(entity player,table s,string reason)
{
    if(expect int(s.rounds)<=0&&expect int(s.reloads)<=0)return
    print("WNOTE_FIRE t="+Time()+" owner="+player.GetEncodedEHandle()+" life="+s.life+" gun="+s.gun+" mods="+s.mods
        +" config="+s.config+" start="+s.start+" end="+s.last+" sampling_valid="+s.valid
        +" rounds="+s.rounds+" ads_rounds="+s.ads+" zoom_known="+file.zoomOk
        +" reloads="+s.reloads+" reason="+reason)
    s.start=s.last
    s.valid=true
    s.rounds=0
    s.ads=0
    s.reloads=0
    s.flushAt=Time()+2.0
}
void function WeaponNotes_KickFlush(table s)
{
    if(expect int(s.burst)>=3)
        print("WNOTE_KICK t="+Time()+" gun="+s.gun+" mods="+s.mods+" config="+s.config+" ads="+s.burstAds
            +" rounds="+s.burst+" dpitch="+s.dpitch+" dyaw="+s.dyaw+" max_dpitch="+s.maxPitch+" max_dyaw="+s.maxYaw
            +" duration="+(expect float(s.burstLast)-expect float(s.burstStart)))
    s.burst=0
    s.dpitch=0.0
    s.dyaw=0.0
    s.maxPitch=0.0
    s.maxYaw=0.0
}
float function WeaponNotes_AngleDelta(float a,float b)
{
    float d=a-b
    while(d>180.0)d-=360.0
    while(d<-180.0)d+=360.0
    return d
}
void function WeaponNotes_FireSampler(entity player,int life)
{
    // Rounds = observed magazine decreases of the local human's active weapon.
    // These are rounds spent, not hits; analysis divides recorded pilot hits by
    // them only for single-projectile guns. View-kick bursts are only meaningful
    // in controlled tests without aiming input (solo_weapon_notes_viewkick 1).
    player.EndSignal("OnDeath")
    player.EndSignal("OnDestroy")
    table s={weapon=null,clip=-1,gun="none",mods="none",life=life,rounds=0,ads=0,reloads=0,flushAt=Time()+2.0,
        config=WeaponNotes_Config(),start=Time(),last=Time(),valid=true,
        burst=0,burstAds=false,burstStart=0.0,burstLast=0.0,origin=<0,0,0>,prev=<0,0,0>,dpitch=0.0,dyaw=0.0,maxPitch=0.0,maxYaw=0.0}
    OnThreadEnd(
        function():(player,s)
        {
            if(!IsValid(player))return
            try{
                WeaponNotes_FireFlush(player,s,"end")
                WeaponNotes_KickFlush(s)
            }catch(endError){}
        }
    )
    bool kick=GetConVarBool("solo_weapon_notes_viewkick")
    s.prev=player.EyeAngles()
    while(true)
    {
        WaitFrame()
        if(!WeaponNotes_FireEnabled())return
        try{
            entity weapon=player.GetActiveWeapon()
            string mods=IsValid(weapon)?WeaponNotes_Mods(weapon):"none"
            string config=WeaponNotes_Config()
            if(weapon!=s.weapon||mods!=s.mods||config!=s.config){
                WeaponNotes_FireFlush(player,s,"change")
                WeaponNotes_KickFlush(s)
                s.weapon=weapon
                s.clip=-1
                s.gun=IsValid(weapon)?weapon.GetWeaponClassName():"none"
                s.mods=mods
                s.config=config
                s.start=Time()
                s.last=Time()
                s.valid=true
            }
            vector angles=player.EyeAngles()
            if(IsValid(weapon)){
                int clip=weapon.GetWeaponPrimaryClipCount()
                bool ads=false
                if(file.zoomOk){
                    try{ads=player.GetZoomFrac()>=0.9}catch(zoomError){file.zoomOk=false}
                }
                if(expect int(s.clip)>=0&&clip<expect int(s.clip)){
                    int fired=expect int(s.clip)-clip
                    s.rounds=expect int(s.rounds)+fired
                    if(ads)s.ads=expect int(s.ads)+fired
                    if(kick){
                        if(expect int(s.burst)==0){s.origin=s.prev;s.burstStart=Time();s.burstAds=ads}
                        s.burst=expect int(s.burst)+fired
                        s.burstLast=Time()
                    }
                }else if(expect int(s.clip)>=0&&clip>expect int(s.clip)){
                    s.reloads=expect int(s.reloads)+1
                    s.valid=false // Reload boundaries can hide a shot between samples.
                }
                if(expect int(s.clip)<0)s.start=Time()
                s.clip=clip
                s.last=Time()
            }else{s.valid=false}
            if(kick&&expect int(s.burst)>0){
                vector origin=expect vector(s.origin)
                float dp=WeaponNotes_AngleDelta(angles.x,origin.x)
                float dy=WeaponNotes_AngleDelta(angles.y,origin.y)
                s.dpitch=dp
                s.dyaw=dy
                if(fabs(dp)>expect float(s.maxPitch))s.maxPitch=fabs(dp)
                if(fabs(dy)>expect float(s.maxYaw))s.maxYaw=fabs(dy)
                if(Time()-expect float(s.burstLast)>0.3)WeaponNotes_KickFlush(s)
            }
            s.prev=angles
            if(Time()>=expect float(s.flushAt))WeaponNotes_FireFlush(player,s,"interval")
        }catch(error){
            s.valid=false
            s.clip=-1 // Never bridge an unknown sampling gap.
            file.fireErrors++
            print("WNOTE_FIRE_ERROR count="+file.fireErrors)
            print(string(error)) // General private game log only; the collector ignores it.
        }
    }
}
