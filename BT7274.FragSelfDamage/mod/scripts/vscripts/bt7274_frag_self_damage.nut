untyped
global function BT7274FragSelfDamage_Init

void function BT7274FragSelfDamage_Init()
{
    // Source callbacks run before final damage observers / the weapon notebook.
    // No native offsets, projectile overrides, fuse edits or health refunds.
    AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_frag_grenade, BT7274FragSelfDamage_OnDamage )
}

void function BT7274FragSelfDamage_OnDamage( entity victim, var damageInfo )
{
    if ( !GetConVarBool( "bt7274_bot_frag_self_damage" )
        || !GetConVarBool( "ns_auth_allow_insecure" ) || IsLobby() ) return
    if ( !IsValid( victim ) || !victim.IsPlayer() || victim.IsTitan()
        || victim.GetUID() != "0" ) return
    entity attacker = DamageInfo_GetAttacker( damageInfo )
    if ( !IsValid( attacker ) || attacker != victim ) return
    if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) != eDamageSourceId.mp_weapon_frag_grenade ) return

    float scale = GetConVarFloat( "bt7274_bot_frag_self_damage_scale" )
    // Invalid/out-of-range policy fails open to normal damage, never amplification.
    if ( !(scale >= 0.0 && scale <= 1.0) ) return
    float before = DamageInfo_GetDamage( damageInfo )
    if ( before <= 0.0 ) return
    DamageInfo_SetDamage( damageInfo, before * scale )
    if ( GetConVarBool( "bt7274_bot_frag_self_damage_log" ) )
        print( "BT_FRAG_SELF_SCALE schema=1 map=" + GetMapName() + " t=" + Time()
            + " before=" + before + " after=" + DamageInfo_GetDamage( damageInfo ) + " scale=" + scale )
}
