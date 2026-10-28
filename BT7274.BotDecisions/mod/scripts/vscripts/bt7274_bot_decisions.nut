untyped
global function BT7274BotDecisions_Init
struct {
    table<int,float> tacticalUse
    table<int,float> ordnanceUse
    table<int,bool> phase
    int observeErrors = 0
} file

void function BT7274BotDecisions_Init()
{
    print( "BOT_DECISIONS: bridge v1.1 ready; readiness/target and observed offhand outcomes" )
    AddCallback_OnWeaponAttack( BT7274BotDecisions_Attack )
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

void function BT7274BotDecisions_Attack(entity player,entity weapon,string weaponName,int shotsFired)
{
    if(!IsValid(player)||player.GetUID()!="0"||player.IsTitan())return
    if(weaponName.find("grenade")==null&&weaponName.find("mp_ability_")!=0&&weaponName!="mp_weapon_deployable_cover")return
    print("BOT_OFFHAND_ATTACK map="+GetMapName()+" t="+Time()+" entity_index="+player.GetEntIndex()+" weapon="+weaponName+" shots="+shotsFired)
}
