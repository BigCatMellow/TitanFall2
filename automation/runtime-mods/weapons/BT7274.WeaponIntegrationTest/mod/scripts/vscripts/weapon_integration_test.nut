untyped
global function WeaponIntegration_Init
struct { bool started = false } file
void function WeaponIntegration_Init()
{
    if ( GetConVarInt("bt7274_candidate_phase") == 6 && GetConVarBool("bt7274_candidate_weapons") )
        AddCallback_GameStateEnter(eGameState.Playing, WeaponIntegration_Start)
}
void function WeaponIntegration_Start()
{
    if ( file.started ) return
    file.started = true
    thread WeaponIntegration_Run()
}
void function WeaponIntegration_Flags(bool reload, bool ads, bool balance)
{
    SetConVarBool("bt7274_weapon_reload",reload)
    SetConVarBool("bt7274_ads_trial",ads)
    SetConVarBool("solo_weapon_balance",balance)
    SetConVarBool("solo_weapon_balance_bots",false)
}
void function WeaponIntegration_Apply(entity player)
{
    BT7274WeaponReload_Apply(player)
    BT7274WeaponHandling_Apply(player)
    SoloWeaponBalance_Apply(player)
}
int function WeaponIntegration_Count(entity weapon,string name)
{
    int result = 0
    foreach ( string mod in weapon.GetMods() ) if ( mod == name ) result++
    return result
}
void function WeaponIntegration_SetGun(entity player,string gun,bool speedloader)
{
    PilotLoadoutDef loadout = GetPilotLoadoutFromPersistentData(player,0)
    loadout.primary = gun
    loadout.primarySkinIndex = 0
    loadout.primaryCamoIndex = 0
    loadout.primaryMod1 = speedloader ? "pas_fast_reload" : ""
    loadout.primaryMod2 = speedloader ? "extended_ammo" : ""
    loadout.primaryMod3 = ""
    loadout.primaryAttachment = ""
    UpdateDerivedPilotLoadoutData(loadout)
    GivePilotLoadout(player,loadout)
}
array<int> function WeaponIntegration_RoleFields(string gun)
{
    if ( gun == "mp_weapon_r97" ) return [eWeaponVar.spread_kick_on_fire_stand_hip,eWeaponVar.spread_kick_on_fire_crouch_hip,eWeaponVar.spread_kick_on_fire_air_hip,
        eWeaponVar.spread_max_kick_stand_hip,eWeaponVar.spread_max_kick_crouch_hip,eWeaponVar.spread_max_kick_air_hip]
    if ( gun == "mp_weapon_lmg" ) return [eWeaponVar.ads_move_speed_scale]
    return [eWeaponVar.viewkick_scale_min_ads,eWeaponVar.viewkick_scale_max_ads]
}
float function WeaponIntegration_RoleScale(string gun)
{
    if ( gun == "mp_weapon_hemlok_smg" ) return 0.75
    if ( gun == "mp_weapon_r97" ) return 0.70
    return 0.80
}
void function WeaponIntegration_Close(float actual,float expected,string context)
{
    WeaponIntegration_Require(fabs(actual-expected)<0.001,"Weapon test mismatch "+context+" actual="+actual+" expected="+expected)
}
void function WeaponIntegration_Run()
{
    wait 1.0
    entity player = null
    float deadline = Time()+30.0
    while ( Time()<deadline )
    {
        foreach ( entity p in GetPlayerArray() )
            if ( p.GetUID()!="0" && IsAlive(p) ) player=p
        if ( IsValid(player) && GetPlayerArray().len() == 16 ) break
        wait 0.25
    }
    WeaponIntegration_Require(IsValid(player)&&IsAlive(player),"No living local human for weapon tests")
    WeaponIntegration_Require(GetPlayerArray().len()==16,"Weapon test population mismatch")
    player.SetInvulnerable()
    print("WEAPON_INTEGRATION: BEGIN map="+GetMapName()+" population=16")
    array<int> reloadFields=[eWeaponVar.reload_time,eWeaponVar.reload_time_late1,eWeaponVar.reload_time_late2,eWeaponVar.reload_time_late3,
        eWeaponVar.reloadempty_time,eWeaponVar.reloadempty_time_late1,eWeaponVar.reloadempty_time_late2,eWeaponVar.reloadempty_time_late3]
    foreach ( string gun in ["mp_weapon_g2","mp_weapon_hemlok_smg","mp_weapon_alternator_smg","mp_weapon_rspn101","mp_weapon_car"] )
    {
        foreach ( bool speedloader in [false,true] )
        {
            WeaponIntegration_Flags(false,false,false)
            WeaponIntegration_SetGun(player,gun,speedloader)
            wait 0.3
            WeaponIntegration_Apply(player)
            entity weapon=player.GetMainWeapons()[0]
            WeaponIntegration_Require(weapon.GetWeaponClassName()==gun,"Wrong reload weapon")
            array<float> baseline
            foreach ( int field in reloadFields ) baseline.append(weapon.GetWeaponSettingFloat(field))
            int damage=weapon.GetWeaponSettingInt(eWeaponVar.damage_near_value)
            float rate=weapon.GetWeaponSettingFloat(eWeaponVar.fire_rate)
            int magazine=weapon.GetWeaponSettingInt(eWeaponVar.ammo_clip_size)
            weapon.SetWeaponPrimaryClipCount(3)
            WeaponIntegration_Flags(true,false,false)
            WeaponIntegration_Apply(player)
            WeaponIntegration_Apply(player)
            foreach ( int index,int field in reloadFields ) WeaponIntegration_Close(weapon.GetWeaponSettingFloat(field),baseline[index]*0.9,gun+" reload")
            WeaponIntegration_Require(WeaponIntegration_Count(weapon,"bt7274_solo_reload")==1,"Duplicate reload modifier")
            WeaponIntegration_Require(weapon.GetWeaponSettingInt(eWeaponVar.damage_near_value)==damage,"Reload changed damage")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.fire_rate),rate,"reload changed rate")
            WeaponIntegration_Require(weapon.GetWeaponSettingInt(eWeaponVar.ammo_clip_size)==magazine,"Reload changed magazine")
            WeaponIntegration_Require(weapon.GetWeaponPrimaryClipCount()==3,"Reload mod refilled ammo")
            WeaponIntegration_Require(!speedloader||(weapon.GetMods().contains("pas_fast_reload")&&weapon.GetMods().contains("extended_ammo")),"Attachments lost")
            float enabledNormal=weapon.GetWeaponSettingFloat(eWeaponVar.reload_time)
            float enabledEmpty=weapon.GetWeaponSettingFloat(eWeaponVar.reloadempty_time)
            WeaponIntegration_Flags(false,false,false)
            WeaponIntegration_Apply(player)
            foreach ( int index,int field in reloadFields ) WeaponIntegration_Close(weapon.GetWeaponSettingFloat(field),baseline[index],gun+" reload off")
            print("WEAPON_CHECK kind=reload gun="+gun+" speedloader="+speedloader+" normal="+baseline[0]+" enabled="+enabledNormal+" empty="+baseline[4]+" enabled_empty="+enabledEmpty)
        }
    }
    foreach ( string gun in ["mp_weapon_vinson","mp_weapon_g2"] )
    {
        foreach ( bool speedloader in [false,true] )
        {
            WeaponIntegration_Flags(true,false,false)
            WeaponIntegration_SetGun(player,gun,speedloader)
            wait 0.3
            WeaponIntegration_Apply(player)
            entity weapon=player.GetMainWeapons()[0]
            float zoomIn=weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_in)
            float zoomOut=weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_out)
            float reload=weapon.GetWeaponSettingFloat(eWeaponVar.reload_time)
            float kick=weapon.GetWeaponSettingFloat(eWeaponVar.viewkick_scale_min_ads)
            WeaponIntegration_Flags(true,true,true)
            WeaponIntegration_Apply(player)
            WeaponIntegration_Apply(player)
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_in),zoomIn*0.75,gun+" ADS in")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_out),zoomOut*0.75,gun+" ADS out")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.reload_time),reload,gun+" ADS/reload collision")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.viewkick_scale_min_ads),kick*(gun=="mp_weapon_vinson"?0.8:1.0),gun+" ADS/balance collision")
            WeaponIntegration_Require(WeaponIntegration_Count(weapon,"bt7274_solo_ads_trial")==1,"Duplicate ADS modifier")
            float enabledIn=weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_in)
            WeaponIntegration_Flags(true,false,false)
            WeaponIntegration_Apply(player)
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_in),zoomIn,gun+" ADS off")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.viewkick_scale_min_ads),kick,gun+" balance off")
            print("WEAPON_CHECK kind=ads gun="+gun+" speedloader="+speedloader+" before="+zoomIn+" enabled="+enabledIn)
        }
    }
    foreach ( string gun in ["mp_weapon_vinson","mp_weapon_hemlok_smg","mp_weapon_r97","mp_weapon_lmg"] )
    {
        foreach ( bool speedloader in [false,true] )
        {
            WeaponIntegration_Flags(true,true,false)
            WeaponIntegration_SetGun(player,gun,speedloader)
            wait 0.3
            WeaponIntegration_Apply(player)
            entity weapon=player.GetMainWeapons()[0]
            array<int> fields=WeaponIntegration_RoleFields(gun)
            array<float> baseline
            foreach ( int field in fields ) baseline.append(weapon.GetWeaponSettingFloat(field))
            int damage=weapon.GetWeaponSettingInt(eWeaponVar.damage_near_value)
            int farDamage=weapon.GetWeaponSettingInt(eWeaponVar.damage_far_value)
            int magazine=weapon.GetWeaponSettingInt(eWeaponVar.ammo_clip_size)
            float rate=weapon.GetWeaponSettingFloat(eWeaponVar.fire_rate)
            float reload=weapon.GetWeaponSettingFloat(eWeaponVar.reload_time)
            float zoom=weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_in)
            weapon.SetWeaponPrimaryClipCount(3)
            WeaponIntegration_Flags(true,true,true)
            WeaponIntegration_Apply(player)
            WeaponIntegration_Apply(player)
            foreach ( int index,int field in fields )
            {
                float effective=weapon.GetWeaponSettingFloat(field)
                WeaponIntegration_Close(effective,baseline[index]*WeaponIntegration_RoleScale(gun),gun+" role field")
                print("WEAPON_VALUE gun="+gun+" speedloader="+speedloader+" index="+index+" field="+field+" before="+baseline[index]+" enabled="+effective)
            }
            WeaponIntegration_Require(WeaponIntegration_Count(weapon,"solo_role_balance_v1")==1,"Duplicate balance modifier")
            WeaponIntegration_Require(weapon.GetWeaponSettingInt(eWeaponVar.damage_near_value)==damage&&weapon.GetWeaponSettingInt(eWeaponVar.damage_far_value)==farDamage,"Balance changed damage")
            WeaponIntegration_Require(weapon.GetWeaponSettingInt(eWeaponVar.ammo_clip_size)==magazine,"Balance changed magazine")
            WeaponIntegration_Require(weapon.GetWeaponPrimaryClipCount()==3,"Balance refilled ammo")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.fire_rate),rate,"Balance changed rate")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.reload_time),reload,"Balance/reload collision")
            WeaponIntegration_Close(weapon.GetWeaponSettingFloat(eWeaponVar.zoom_time_in),zoom,"Balance/ADS collision")
            WeaponIntegration_Require(!speedloader||(weapon.GetMods().contains("pas_fast_reload")&&weapon.GetMods().contains("extended_ammo")),"Role attachments lost")
            WeaponIntegration_Flags(true,true,false)
            WeaponIntegration_Apply(player)
            foreach ( int index,int field in fields ) WeaponIntegration_Close(weapon.GetWeaponSettingFloat(field),baseline[index],gun+" role off")
            print("WEAPON_CHECK kind=balance gun="+gun+" speedloader="+speedloader)
        }
    }
    WeaponIntegration_Flags(true,true,true)
    foreach ( string gun in ["mp_weapon_rspn101","mp_weapon_car","mp_weapon_g2","mp_weapon_vinson","mp_weapon_hemlok_smg","mp_weapon_r97","mp_weapon_lmg"] )
    {
        WeaponIntegration_SetGun(player,gun,false)
        wait 0.3
        entity weapon=player.GetMainWeapons()[0]
        bool reload=["mp_weapon_rspn101","mp_weapon_car","mp_weapon_g2","mp_weapon_hemlok_smg"].contains(gun)
        bool ads=["mp_weapon_g2","mp_weapon_vinson"].contains(gun)
        bool balance=["mp_weapon_vinson","mp_weapon_hemlok_smg","mp_weapon_r97","mp_weapon_lmg"].contains(gun)
        WeaponIntegration_Require(weapon.GetMods().contains("bt7274_solo_reload")==reload,"Automatic reload application failed")
        WeaponIntegration_Require(weapon.GetMods().contains("bt7274_solo_ads_trial")==ads,"Automatic ADS application/control failed")
        WeaponIntegration_Require(weapon.GetMods().contains("solo_role_balance_v1")==balance,"Automatic balance application/control failed")
        print("WEAPON_CHECK kind=automatic gun="+gun)
    }
    entity testBot=null
    foreach ( entity p in GetPlayerArray() ) if(p.GetUID()=="0"&&IsAlive(p)&&!p.IsTitan())testBot=p
    WeaponIntegration_Require(IsValid(testBot),"No pilot bot for exclusion test")
    testBot.SetInvulnerable()
    foreach ( string gun in ["mp_weapon_vinson","mp_weapon_hemlok_smg","mp_weapon_g2"] )
    {
        WeaponIntegration_SetGun(testBot,gun,true)
        wait 0.3
        entity weapon=testBot.GetMainWeapons()[0]
        array<string> mods=weapon.GetMods()
        WeaponIntegration_Require(!mods.contains("bt7274_solo_reload")&&!mods.contains("bt7274_solo_ads_trial")&&!mods.contains("solo_role_balance_v1"),"Bot unexpectedly opted in")
        if(gun!="mp_weapon_vinson")mods.append("bt7274_solo_reload")
        if(gun!="mp_weapon_hemlok_smg")mods.append("bt7274_solo_ads_trial")
        if(gun!="mp_weapon_g2")mods.append("solo_role_balance_v1")
        weapon.SetMods(mods)
        WeaponIntegration_Apply(testBot)
        mods=weapon.GetMods()
        WeaponIntegration_Require(!mods.contains("bt7274_solo_reload")&&!mods.contains("bt7274_solo_ads_trial")&&!mods.contains("solo_role_balance_v1"),"Bot retained forced human modifier")
        WeaponIntegration_Require(mods.contains("pas_fast_reload")&&mods.contains("extended_ammo"),"Bot's normal attachments lost")
        print("WEAPON_CHECK kind=bot_exclusion_and_strip gun="+gun)
    }
    GivePilotLoadout(testBot,GetPilotLoadoutFromPersistentData(testBot,0))
    testBot.ClearInvulnerable()
    GivePilotLoadout(player,GetPilotLoadoutFromPersistentData(player,0))
    wait 0.5
    player.ClearInvulnerable()
    player.Die()
    deadline=Time()+25.0
    while(!IsAlive(player)&&Time()<deadline)wait 0.25
    WeaponIntegration_Require(IsAlive(player),"Human failed to respawn after weapon checks")
    WeaponIntegration_Require(fabs(GetConVarFloat("bot_aim_error_scale")-0.78)<0.001,"Bot aim setting changed")
    WeaponIntegration_Require(!GetConVarBool("solo_weapon_balance_bots"),"Bots remained opted in")
    print("WEAPON_INTEGRATION: COMPLETE reload_cases=10 ads_cases=4 balance_cases=8 automatic_cases=7 bot_strip_cases=3 respawn=true bots_opt_in=false")
}

void function WeaponIntegration_Require(bool condition,string message)
{
    if(!condition)throw message
}
