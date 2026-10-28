untyped
global function BT7274BotDecisions_Init
struct {
    table<int,float> tacticalUse
    table<int,float> ordnanceUse
    table<int,bool> phase
    table<int,float> fragPrep
    table<int,bool> projectiles
    int observeErrors = 0
} file

void function BT7274BotDecisions_Init()
{
    print( "BOT_DECISIONS: bridge v1.2 ready; readiness/target, offhand outcomes and owned frag trajectories" )
    AddCallback_OnWeaponAttack( BT7274BotDecisions_Attack )
    AddCallback_OnPlayerRespawned( BT7274BotDecisions_Respawn )
    AddDamageFinalCallback("player",BT7274BotDecisions_GrenadeDamage)
    thread BT7274BotDecisions_Update()
}
float function BT7274BotDecisions_Cost( entity weapon )
{
    return max( 1, max( weapon.GetAmmoPerShot(), weapon.GetWeaponCurrentEnergyCost() ) )
}
bool function BT7274BotDecisions_Ready( entity weapon )
{
    if ( !IsValid( weapon ) ) return false
    return weapon.IsReadyToFire() && !weapon.IsWeaponRegenDraining()
        && weapon.GetWeaponPrimaryClipCount() >= BT7274BotDecisions_Cost( weapon )
}
void function BT7274BotDecisions_Update()
{
    float nextLog = 0.0
    while ( true )
    {
        bool emit = Time() >= nextLog
        if ( emit ) nextLog = Time() + 2.0
        foreach ( entity player in GetPlayerArray() )
        {
            if ( !IsValid( player ) ) continue
            entity pet = player.GetPetTitan()
            if ( IsValid( pet ) && IsAlive( pet ) )
                BotReportTargetEligibility( pet, !pet.e.isHotDropping, Time() )
            if ( player.GetUID() != "0" || !IsAlive( player ) || player.IsTitan() ) continue
            entity tactical = player.GetOffhandWeapon( OFFHAND_LEFT )
            entity ordnance = player.GetOffhandWeapon( OFFHAND_RIGHT )
            bool tacReady = BT7274BotDecisions_Ready( tactical )
            bool ordReady = BT7274BotDecisions_Ready( ordnance )
            BotReportReadiness( player, tactical, tacReady, ordnance, ordReady, Time() )
            if(file.observeErrors<3){
                try{BT7274BotDecisions_Observe(player,tactical,ordnance)}
                catch(error){file.observeErrors++;print("BOT_OBSERVE_ERROR count="+file.observeErrors);print(string(error))}
            }
            if ( emit && IsValid( tactical ) && IsValid( ordnance ) )
                print( "BOT_READY map=" + GetMapName() + " t=" + Time() + " entity_index=" + player.GetEntIndex()
                    + " tactical=" + tactical.GetWeaponClassName() + " tactical_ready=" + tacReady
                    + " tactical_clip=" + tactical.GetWeaponPrimaryClipCount() + " tactical_shots=" + tactical.GetShotCount()
                    + " tactical_cost=" + BT7274BotDecisions_Cost( tactical )
                    + " ordnance=" + ordnance.GetWeaponClassName() + " ordnance_ready=" + ordReady
                    + " ordnance_clip=" + ordnance.GetWeaponPrimaryClipCount() + " ordnance_shots=" + ordnance.GetShotCount()
                    + " ordnance_cost=" + BT7274BotDecisions_Cost( ordnance ) )
        }
        wait 0.1
    }
}

void function BT7274BotDecisions_Observe(entity player,entity tactical,entity ordnance)
{
    int id=player.GetEncodedEHandle()
    float tac=player.p.lastPilotOffhandUseTime[OFFHAND_LEFT]
    float ord=player.p.lastPilotOffhandUseTime[OFFHAND_RIGHT]
    bool phase=player.IsPhaseShifted()
    entity active=player.GetActiveWeapon()
    if(IsValid(active)&&active.GetWeaponClassName()=="mp_weapon_frag_grenade"&&active.w.startChargeTime>0){
        float prep=active.w.startChargeTime
        if(!(id in file.fragPrep)||file.fragPrep[id]!=prep){
            file.fragPrep[id]<-prep
            print("BOT_FRAG_PREP map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" prep_t="+prep+" age="+(Time()-prep))
        }
    }
    if((!(id in file.tacticalUse)||file.tacticalUse[id]!=tac)&&tac>=Time()-0.5&&tac>0&&IsValid(tactical))
        print("BOT_OFFHAND_USED map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" channel=tactical weapon="+tactical.GetWeaponClassName()+" used_t="+tac)
    if((!(id in file.ordnanceUse)||file.ordnanceUse[id]!=ord)&&ord>=Time()-0.5&&ord>0&&IsValid(ordnance))
        print("BOT_OFFHAND_USED map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" channel=ordnance weapon="+ordnance.GetWeaponClassName()+" used_t="+ord)
    if((phase&&!(id in file.phase))||(id in file.phase&&file.phase[id]!=phase))
        print("BOT_PHASE map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" active="+phase)
    file.tacticalUse[id]<-tac
    file.ordnanceUse[id]<-ord
    file.phase[id]<-phase
}

void function BT7274BotDecisions_Respawn(entity player)
{
    if(player.GetUID()=="0")thread BT7274BotDecisions_Throws(player)
}
void function BT7274BotDecisions_Throws(entity player)
{
    WaitEndFrame()
    if(!IsValid(player)||!IsAlive(player))return
    player.EndSignal("OnDestroy")
    player.EndSignal("OnDeath")
    player.EndSignal("OnRespawned")
    while(true){
        player.WaitSignal("ThrowGrenade")
        if(file.observeErrors>=3)return
        if(!IsAlive(player)||player.IsTitan())continue
        try{
            entity left=player.GetOffhandWeapon(OFFHAND_LEFT)
            entity right=player.GetOffhandWeapon(OFFHAND_RIGHT)
            float lp=IsValid(left)?left.w.startChargeTime:0.0
            float rp=IsValid(right)?right.w.startChargeTime:0.0
            entity thrown=lp>rp?left:right
            float prep=max(lp,rp)
            string name=IsValid(thrown)&&prep>0&&Time()-prep<8?thrown.GetWeaponClassName():"unknown"
            float age=name!="unknown"?Time()-prep:-1.0
            print("BOT_THROW_RELEASE map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" weapon="+name+" prep_age="+age)
            WaitEndFrame()
            array<entity> nearby=GetProjectileArrayEx("any",TEAM_ANY,TEAM_ANY,player.GetOrigin(),1800)
            int owned=0
            foreach(entity grenade in nearby){
                bool mine=grenade.GetOwner()==player
                if(!mine&&("originalOwner" in grenade.s))mine=grenade.s.originalOwner==player
                if(!mine)continue
                owned++
                if(grenade.ProjectileGetDamageSourceID()!=eDamageSourceId.mp_weapon_frag_grenade)continue
                int id=grenade.GetEncodedEHandle()
                if(id in file.projectiles)continue
                file.projectiles[id]<-true
                thread BT7274BotDecisions_Projectile(player,grenade)
            }
            print("BOT_PROJECTILE_SCAN map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" nearby="+nearby.len()+" owned="+owned)
        }catch(error){file.observeErrors++;print("BOT_OBSERVE_ERROR stage=throw count="+file.observeErrors);print(string(error))}
    }
}
void function BT7274BotDecisions_Projectile(entity player,entity grenade)
{
    player.EndSignal("OnDestroy")
    player.EndSignal("OnDeath")
    float until=Time()+5.0
    while(Time()<until&&IsValid(grenade)&&IsValid(player)&&IsAlive(player)){
        vector p=grenade.GetOrigin()
        vector v=grenade.GetVelocity()
        float dist=Distance(player.GetOrigin(),p)
        print("BOT_PROJECTILE map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" projectile="+grenade.GetEncodedEHandle()+" x="+p.x+" y="+p.y+" z="+p.z+" vx="+v.x+" vy="+v.y+" vz="+v.z+" owner_dist="+dist)
        wait 0.25
    }
}

void function BT7274BotDecisions_Attack(entity player,entity weapon,string weaponName,int shotsFired)
{
    if(!IsValid(player)||player.GetUID()!="0"||player.IsTitan())return
    if(weaponName.find("grenade")==null&&weaponName.find("mp_ability_")!=0&&weaponName!="mp_weapon_deployable_cover")return
    print("BOT_OFFHAND_ATTACK map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" weapon="+weaponName+" shots="+shotsFired)
}
void function BT7274BotDecisions_GrenadeDamage(entity victim,var info)
{
    if(file.observeErrors>=3)return
    try{
        entity attacker=DamageInfo_GetAttacker(info)
        if(!IsValid(attacker)||!attacker.IsPlayer()||attacker.GetUID()!="0"||attacker.IsTitan())return
        if(DamageInfo_GetDamageWeaponName(info)!="mp_weapon_frag_grenade")return
        entity projectile=DamageInfo_GetInflictor(info)
        if(!IsValid(projectile))return
        vector p=projectile.GetOrigin()
        vector v=projectile.GetVelocity()
        print("BOT_GRENADE_DAMAGE map="+GetMapName()+" t="+Time()+" entity_index="+attacker.GetEntIndex()+" self="+(attacker==victim)+" class="+projectile.GetClassName()+" owner_dist="+Distance(attacker.GetOrigin(),p)+" vx="+v.x+" vy="+v.y+" vz="+v.z)
    }catch(error){file.observeErrors++;print("BOT_OBSERVE_ERROR stage=grenade_damage count="+file.observeErrors);print(string(error))}
}
