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

// Defensive tacticals the native controller already knows how to request
// (Stim and Phase Shift); remaining ranks keep their current tactical.
string function BT7274BotRoster_Tactical( int rank )
{
    int r = rank % 8
    if ( r == 0 || r == 3 || r == 6 ) return "mp_ability_heal"
    if ( r == 2 || r == 5 ) return "mp_ability_shifter"
    return ""
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
    entity weapon = bot.GetOffhandWeapon( 1 ) // tactical slot (native reads offhandWeapons[1])
    return IsValid( weapon ) ? weapon.GetWeaponClassName() : "none"
}

void function BT7274BotRoster_Give( entity bot, PilotLoadoutDef loadout )
{
    UpdateDerivedPilotLoadoutData( loadout )
    GivePilotLoadout( bot, loadout )
    string tactical = BT7274BotRoster_TacticalClass( bot )
    file.suitTactical[ loadout.suit ] <- tactical
    file.tacticalSuit[ tactical ] <- loadout.suit
}

void function BT7274BotRoster_Apply( entity bot )
{
    WaitEndFrame()
    if ( !IsValid( bot ) || !IsAlive( bot ) || bot.IsTitan() || !BT7274BotRoster_Enabled() ) return
    try
    {
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
        string wanted = GetConVarBool( "bt7274_bot_tacticals" ) ? BT7274BotRoster_Tactical( rank ) : ""
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
        print( "BOT_ROSTER map=" + GetMapName() + " slot=" + bot.GetEntIndex() + " team=" + bot.GetTeam()
            + " rank=" + rank + " primary=" + loadout.primary + " suit=" + loadout.suit
            + " tactical=" + BT7274BotRoster_TacticalClass( bot ) + " wanted=" + ( wanted == "" ? "keep" : wanted ) )
    }
    catch ( error )
    {
        file.errors++
        print( "BOT_ROSTER_ERROR count=" + file.errors )
        print( string( error ) )
    }
}
