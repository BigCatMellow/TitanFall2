untyped
global function BT7274FragAwareness_Init
struct {
    table frags
    bool fault=false
} file
void function BT7274FragAwareness_Init(){
    if(!GetConVarBool("bt7274_frag_awareness"))return
    print("BT_FRAG_AWARE_READY t="+Time())
    thread BT7274FragAwareness_Run()
}
bool function BT7274FragAwareness_Bot(entity p){
    return IsValid(p)&&p.IsPlayer()&&!p.IsTitan()&&p.GetUID()=="0"
}
void function BT7274FragAwareness_Run(){
    while(GetConVarBool("bt7274_frag_awareness")&&!file.fault){
        wait 0.1
        if(IsLobby())continue
        try{
            float now=Time()
            array<entity> projectiles=GetProjectileArrayEx("any",TEAM_ANY,TEAM_ANY,Vector(0,0,0),50000)
            foreach(entity grenade in projectiles){
                if(!IsValid(grenade)||grenade.ProjectileGetDamageSourceID()!=eDamageSourceId.mp_weapon_frag_grenade)continue
                entity owner=grenade.GetOwner()
                if(!BT7274FragAwareness_Bot(owner)&&("originalOwner" in grenade.s))owner=expect entity(grenade.s.originalOwner)
                if(!BT7274FragAwareness_Bot(owner)||!IsAlive(owner))continue
                int id=grenade.GetEncodedEHandle()
                if(!(id in file.frags))file.frags[id]<-{first=now,last=now,next=now}
                table row=expect table(file.frags[id]);row.last=now
                vector pos=grenade.GetOrigin();vector vel=grenade.GetVelocity()
                float age=now-expect float(row.first)
                BotReportOwnedFrag(owner,grenade,pos,vel,age,now)
                if(now>=row.next){
                    vector o=owner.GetOrigin()
                    print("BT_FRAG_AWARE_SAMPLE t="+now+" owner="+owner.GetEncodedEHandle()+" projectile="+id+" age="+(now-row.first)
                        +" distance="+Distance(o,pos)+" gx="+pos.x+" gy="+pos.y+" gz="+pos.z+" ox="+o.x+" oy="+o.y+" oz="+o.z
                        +" vx="+vel.x+" vy="+vel.y+" vz="+vel.z)
                    row.next=now+0.5
                }
            }
            array<int> stale
            foreach(int id,var value in file.frags){table row=expect table(value);if(now-row.last>0.5)stale.append(id)}
            foreach(int id in stale)delete file.frags[id]
        }catch(error){file.fault=true;print("BT_FRAG_AWARE_ERROR t="+Time()+" reason="+error)}
    }
}
