untyped
global function BT7274BotRoster_Init

// Bots only (UID "0"). Each team gets the SAME roster by rank (bots sorted by
// entity index within their team), so the human's allies and enemies match.
// Uses the loadout path already exercised by the isolated weapon matrix:
// GetPilotLoadoutFromPersistentData -> UpdateDerivedPilotLoadoutData -> GivePilotLoadout.
// No damage, fire-rate, aim or attachment changes; primaries are stock (no mods).
struct {
    table suitTactical = {}   // suit -> tactical class observed after giving it
    table tacticalSuit = {}   // tactical class -> suit
    int errors = 0
} file

void function BT7274BotRoster_Init()
{
    AddCallback_OnPlayerRespawned( BT7274BotRoster_Respawn )
}

bool function BT7274BotRoster_Enabled()
{
    return file.errors < 3 && !IsLobby()
        && ( GetConVarBool( "bt7274_bot_roster" ) || GetConVarBool( "bt7274_bot_tacticals" ) )
}

// Range-matched mix. Excluded on purpose: one-shot or near one-shot guns
// (Kraber, shotguns, Mastiff), splash launchers (EPG, Softball, SMR) and the
// heat-based L-STAR, which the bot reload logic does not manage.
array<string> function BT7274BotRoster_Guns()
{
    return [ "mp_weapon_rspn101", "mp_weapon_g2", "mp_weapon_car", "mp_weapon_vinson",
        "mp_weapon_dmr", "mp_weapon_lmg", "mp_weapon_hemlok", "mp_weapon_r97" ]
}

// Skills matched to the gun's personality (same index as BT7274BotRoster_Guns).
// Every tactical/ordnance here has a situational rule in the native
// skill policy (bot_skill_use): Grapple and satchels are deliberately absent.
string function BT7274BotRoster_Tactical( int rank )
{
    array<string> tacticals = [ "mp_weapon_grenade_sonar", "mp_ability_cloak", "mp_ability_heal",
        "mp_ability_holopilot", "mp_ability_cloak", "mp_weapon_deployable_cover", "mp_ability_shifter", "mp_ability_heal" ]
    return tacticals[ rank % tacticals.len() ]
}
string function BT7274BotRoster_Ordnance( int rank )
{
    array<string> ordnance = [ "mp_weapon_frag_grenade", "mp_weapon_grenade_electric_smoke", "mp_weapon_frag_grenade",
        "mp_weapon_grenade_emp", "mp_weapon_grenade_gravity", "mp_weapon_frag_grenade", "mp_weapon_thermite_grenade", "mp_weapon_grenade_emp" ]
    return ordnance[ rank % ordnance.len() ]
}

array<string> function BT7274BotRoster_Suits()
{
    return [ "light", "nomad", "stalker", "geist", "medium", "heavy", "grapple" ]
}

void function BT7274BotRoster_Respawn( entity player )
{
    if ( !IsValid( player ) || player.GetUID() != "0" || !BT7274BotRoster_Enabled() ) return
    thread BT7274BotRoster_Apply( player )
}

int function BT7274BotRoster_Rank( entity bot )
{
    int rank = 0
    foreach ( entity p in GetPlayerArrayOfTeam( bot.GetTeam() ) )
        if ( IsValid( p ) && p.GetUID() == "0" && p.GetEntIndex() < bot.GetEntIndex() ) rank++
    return rank
}

string function BT7274BotRoster_TacticalClass( entity bot )
{
    entity weapon = bot.GetOffhandWeapon( OFFHAND_LEFT ) // tactical slot, as in BT7274.BotDecisions
    return IsValid( weapon ) ? weapon.GetWeaponClassName() : "none"
}

void function BT7274BotRoster_Give( entity bot, PilotLoadoutDef loadout )
{
    UpdateDerivedPilotLoadoutData( loadout )
    GivePilotLoadout( bot, loadout )
    // GivePilotLoadout may apply inventory at end-of-frame. Never cache stale readback.
    WaitEndFrame()
    if ( !IsValid( bot ) || !IsAlive( bot ) || bot.IsTitan() || !BT7274BotRoster_Enabled() )
        throw "Roster assignment interrupted"
    string tactical = BT7274BotRoster_TacticalClass( bot )
    if ( tactical == "none" ) throw "Tactical readback unavailable"
    file.suitTactical[ loadout.suit ] <- tactical
    file.tacticalSuit[ tactical ] <- loadout.suit
}

void function BT7274BotRoster_Apply( entity bot )
{
    WaitEndFrame()
    if ( !IsValid( bot ) || !IsAlive( bot ) || bot.IsTitan() || !BT7274BotRoster_Enabled() ) return
    bot.EndSignal( "OnDeath" )
    bot.EndSignal( "OnDestroy" )
    try
    {
    // Capture the typed struct directly. Respawn's Squirrel dialect cannot
    // cast a var/table slot back to a complex PilotLoadoutDef struct.
    PilotLoadoutDef baseline = GetPilotLoadoutFromPersistentData( bot, 0 )
    table restore = { committed = false }
    OnThreadEnd(
        function():(bot,restore,baseline)
        {
            if ( restore.committed || !IsValid( bot ) || !IsAlive( bot ) || bot.IsTitan() ) return
            try {
                // The saved pre-trial baseline is retained independently of the probe loadout.
                UpdateDerivedPilotLoadoutData( baseline )
                GivePilotLoadout( bot, baseline )
                print( "BOT_ROSTER_RESTORED slot=" + bot.GetEntIndex() )
            } catch ( restoreError ) {
                file.errors++
                print( "BOT_ROSTER_ERROR stage=restore count=" + file.errors )
                print( string( restoreError ) )
            }
        }
    )
        int rank = BT7274BotRoster_Rank( bot )
        PilotLoadoutDef loadout = GetPilotLoadoutFromPersistentData( bot, 0 )
        if ( GetConVarBool( "bt7274_bot_roster" ) )
        {
            array<string> guns = BT7274BotRoster_Guns()
            loadout.primary = guns[ rank % guns.len() ]
            loadout.primaryAttachment = ""
            loadout.primaryMod1 = ""
            loadout.primaryMod2 = ""
            loadout.primaryMod3 = ""
            loadout.primarySkinIndex = 0
            loadout.primaryCamoIndex = 0
        }
        bool skills = GetConVarBool( "bt7274_bot_tacticals" )
        string wanted = skills ? BT7274BotRoster_Tactical( rank ) : ""
        if ( skills ) loadout.ordnance = BT7274BotRoster_Ordnance( rank )
        if ( wanted != "" && wanted in file.tacticalSuit ) loadout.suit = expect string( file.tacticalSuit[ wanted ] )
        BT7274BotRoster_Give( bot, loadout )
        // The suit -> tactical mapping is learned from the game instead of
        // assumed; untried suits are probed at most once per map script VM.
        if ( wanted != "" && BT7274BotRoster_TacticalClass( bot ) != wanted )
        {
            foreach ( string suit in BT7274BotRoster_Suits() )
            {
                if ( suit in file.suitTactical ) continue
                loadout.suit = suit
                BT7274BotRoster_Give( bot, loadout )
                if ( BT7274BotRoster_TacticalClass( bot ) == wanted ) break
            }
        }
        if ( wanted != "" && BT7274BotRoster_TacticalClass( bot ) != wanted ) {
            // Do not leave the last arbitrary probe suit equipped or call it success.
            throw "No verified suit mapping for requested tactical: " + wanted
        }
        if ( !BT7274BotRoster_Enabled() ) throw "Roster disabled before assignment committed"
        restore.committed = true
        print( "BOT_ROSTER map=" + GetMapName() + " slot=" + bot.GetEntIndex() + " team=" + bot.GetTeam()
            + " rank=" + rank + " primary=" + loadout.primary + " suit=" + loadout.suit
            + " tactical=" + BT7274BotRoster_TacticalClass( bot ) + " wanted=" + ( wanted == "" ? "keep" : wanted )
            + " ordnance=" + loadout.ordnance )
    }
    catch ( error )
    {
        file.errors++
        print( "BOT_ROSTER_ERROR count=" + file.errors )
        print( string( error ) )
    }
}
