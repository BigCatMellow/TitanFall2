untyped
global function BT7274FragDamageProbe_Init

// Server-only, default OFF. Records actual frag damage callbacks, not kills.
// This observer does not change damageInfo or block any callback.
struct {
    bool errorLogged = false
} bt7274FragDamageProbeState

void function BT7274FragDamageProbe_Init()
{
    AddDamageFinalCallback( "player", BT7274FragDamageProbe_OnDamage )
}

void function BT7274FragDamageProbe_OnDamage( entity victim, var damageInfo )
{
    try
    {
        if ( !GetConVarBool( "bt7274_frag_damage_probe" )
            || !GetConVarBool( "ns_auth_allow_insecure" ) || IsLobby() ) return
        if ( !IsValid( victim ) || !victim.IsPlayer() || victim.IsTitan() ) return
        if ( DamageInfo_GetDamageSourceIdentifier( damageInfo ) != eDamageSourceId.mp_weapon_frag_grenade ) return
        float damage = DamageInfo_GetDamage( damageInfo )
        if ( damage <= 0.0 ) return
        entity attacker = DamageInfo_GetAttacker( damageInfo )
        if ( !IsValid( attacker ) || !attacker.IsPlayer()
            || attacker.IsTitan() || attacker.GetUID() != "0" ) return

        entity inflictor = DamageInfo_GetInflictor( damageInfo )
        int inflictorId = IsValid( inflictor ) ? inflictor.GetEncodedEHandle() : -1
        string relation = attacker == victim ? "self" :
            ( attacker.GetTeam() == victim.GetTeam() ? "friendly" : "enemy" )
        print( "BT_FRAG_DAMAGE schema=1 map=" + GetMapName() + " t=" + Time()
            + " attacker=" + attacker.GetEncodedEHandle()
            + " victim=" + victim.GetEncodedEHandle()
            + " inflictor=" + inflictorId + " relation=" + relation
            + " damage=" + damage )
    }
    catch ( probeError )
    {
        // A failed diagnostic must never block a legitimate damage callback.
        if ( !bt7274FragDamageProbeState.errorLogged )
        {
            bt7274FragDamageProbeState.errorLogged = true
            print( "BT_FRAG_DAMAGE_ERROR schema=1" )
        }
    }
}
