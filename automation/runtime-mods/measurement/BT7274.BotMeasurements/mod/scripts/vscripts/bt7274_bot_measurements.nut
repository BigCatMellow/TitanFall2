untyped
global function BT7274BotMeasurements_Init
struct {
    table windows
    table lives
    table frags
    int errors=0
} file
void function BT7274BotMeasurements_Init()
{
    if(!GetConVarBool("bt7274_bot_measurements"))return
    AddCallback_OnWeaponAttack(BT7274BotMeasurements_Attack)
    AddCallback_OnPlayerRespawned(BT7274BotMeasurements_Respawn)
    AddCallback_OnPlayerKilled(BT7274BotMeasurements_Killed)
    print("BOT_MEASURE_READY version=1.0.0")
    thread BT7274BotMeasurements_Run()
}
bool function BT7274BotMeasurements_Pilot(entity p)
{
    return IsValid(p)&&p.IsPlayer()&&p.GetUID()=="0"&&!p.IsTitan()
}
bool function BT7274BotMeasurements_Gun(string name)
{
    return ["mp_weapon_rspn101","mp_weapon_g2","mp_weapon_vinson","mp_weapon_dmr",
        "mp_weapon_lmg","mp_weapon_hemlok","mp_weapon_car","mp_weapon_r97"].contains(name)
}
void function BT7274BotMeasurements_Error(var error)
{
    file.errors++
    print("BOT_MEASURE_ERROR count="+file.errors)
    print(string(error))
}
void function BT7274BotMeasurements_Flush(int owner,string reason)
{
    if(!(owner in file.windows))return
    table s=expect table(file.windows[owner])
    print("BWEAPON_WINDOW map="+GetMapName()+" t="+Time()+" owner="+owner+" life="+s.life+" gun="+s.gun
        +" start="+s.start+" samples="+s.samples+" attacks="+s.attacks+" shots_parameter="+s.shots
        +" ammo_decreases="+s.spent+" clip_increases="+s.refills+" reason="+reason)
    s.start=Time()
    s.samples=0
    s.attacks=0
    s.shots=0
    s.spent=0
    s.refills=0
}
table function BT7274BotMeasurements_Window(entity player,entity weapon)
{
    int id=player.GetEncodedEHandle()
    if(!(id in file.lives))file.lives[id]<-1
    if(id in file.windows&&file.windows[id].weapon!=weapon){
        BT7274BotMeasurements_Flush(id,"weapon_change")
        delete file.windows[id]
    }
    if(!(id in file.windows))file.windows[id]<-{
        weapon=weapon,gun=weapon.GetWeaponClassName(),life=file.lives[id],clip=-1,start=Time(),
        samples=0,attacks=0,shots=0,spent=0,refills=0
    }
    return expect table(file.windows[id])
}
void function BT7274BotMeasurements_Respawn(entity p)
{
    if(!IsValid(p)||p.GetUID()!="0")return
    int id=p.GetEncodedEHandle()
    if(id in file.windows){BT7274BotMeasurements_Flush(id,"respawn");delete file.windows[id]}
    if(!(id in file.lives))file.lives[id]<-0
    file.lives[id]++
}
void function BT7274BotMeasurements_Attack(entity p,entity weapon,string name,int shots)
{
    if(file.errors>=3||!BT7274BotMeasurements_Pilot(p)||!IsValid(weapon)||!BT7274BotMeasurements_Gun(name))return
    try{
        table s=BT7274BotMeasurements_Window(p,weapon)
        s.attacks++
        s.shots+=max(0,shots)
    }catch(error){BT7274BotMeasurements_Error(error)}
}
void function BT7274BotMeasurements_Killed(entity victim,entity attacker,var info)
{
    if(file.errors>=3)return
    try{
        if(BT7274BotMeasurements_Pilot(attacker)&&IsValid(victim)&&victim.IsPlayer()&&!victim.IsTitan()
            &&DamageInfo_GetDamageWeaponName(info)=="mp_weapon_frag_grenade"){
            entity projectile=DamageInfo_GetInflictor(info)
            int id=IsValid(projectile)?projectile.GetEncodedEHandle():-1
            print("BFRAG_KILL map="+GetMapName()+" t="+Time()+" projectile="+id
                +" observed="+(id in file.frags)+" self="+(attacker==victim)
                +" friendly="+(attacker!=victim&&attacker.GetTeam()==victim.GetTeam()))
        }
        if(IsValid(victim)&&victim.GetUID()=="0"){
            int owner=victim.GetEncodedEHandle()
            if(owner in file.windows){BT7274BotMeasurements_Flush(owner,"death");delete file.windows[owner]}
        }
    }catch(error){BT7274BotMeasurements_Error(error)}
}
void function BT7274BotMeasurements_Run()
{
    while(file.errors<3&&GetConVarBool("bt7274_bot_measurements")){
        wait 0.1
        if(IsLobby())continue
        try{
            foreach(entity p in GetPlayerArray()){
                if(!BT7274BotMeasurements_Pilot(p)||!IsAlive(p))continue
                entity w=p.GetActiveWeapon()
                int id=p.GetEncodedEHandle()
                if(!IsValid(w)||!BT7274BotMeasurements_Gun(w.GetWeaponClassName())){
                    if(id in file.windows){BT7274BotMeasurements_Flush(id,"inactive");delete file.windows[id]}
                    continue
                }
                table s=BT7274BotMeasurements_Window(p,w)
                int clip=w.GetWeaponPrimaryClipCount()
                if(s.clip>=0&&clip<s.clip)s.spent+=s.clip-clip
                if(s.clip>=0&&clip>s.clip)s.refills++
                s.clip=clip
                s.samples++
                if(Time()-s.start>=2.0)BT7274BotMeasurements_Flush(id,"interval")
            }
            array<entity> projectiles=GetProjectileArrayEx("any",TEAM_ANY,TEAM_ANY,Vector(0,0,0),50000)
            foreach(entity grenade in projectiles){
                if(!IsValid(grenade)||grenade.ProjectileGetDamageSourceID()!=eDamageSourceId.mp_weapon_frag_grenade)continue
                entity owner=grenade.GetOwner()
                if(!BT7274BotMeasurements_Pilot(owner)&&("originalOwner" in grenade.s))owner=expect entity(grenade.s.originalOwner)
                if(!BT7274BotMeasurements_Pilot(owner))continue
                int id=grenade.GetEncodedEHandle()
                vector origin=grenade.GetOrigin()
                float distance=Distance(owner.GetOrigin(),origin)
                if(!(id in file.frags)){
                    vector velocity=grenade.GetVelocity()
                    file.frags[id]<-{first=Time(),last=Time(),next=Time(),minDist=distance}
                    print("BFRAG_SPAWN map="+GetMapName()+" t="+Time()+" projectile="+id
                        +" owner="+owner.GetEncodedEHandle()+" owner_dist="+distance
                        +" speed="+Distance(velocity,Vector(0,0,0)))
                }
                table tracked=expect table(file.frags[id])
                tracked.last=Time()
                tracked.minDist=min(tracked.minDist,distance)
                if(Time()>=tracked.next){
                    print("BFRAG_SAMPLE map="+GetMapName()+" t="+Time()+" projectile="+id
                        +" age="+(Time()-tracked.first)+" owner_dist="+distance+" min_owner_dist="+tracked.minDist)
                    tracked.next=Time()+0.5
                }
            }
        }catch(error){BT7274BotMeasurements_Error(error)}
    }
}
