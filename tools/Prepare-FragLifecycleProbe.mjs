// Prepare an isolated diagnostic _grenade.nut copy from the locally installed source.
// Does NOT edit, install or overwrite game files; fail closed on unknown signatures.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

export const stages = [
  'prep', 'spawn', 'spawn_null', 'release_callback',
  'cancel_drop_callback', 'forced_release_request', 'death_drop',
];
const hook = String.raw`
// BT-7274 isolated frag lifecycle probe. NOT a standalone mod.
// This helper is inert unless the native bot_frag_input_probe convar is on.
// Server only: no gameplay input, damage, fuse or projectile physics changes.
// A diagnostic failure must never abort the underlying toss callback.
struct { bool errorLogged = false } bt7274FragProbeState
void function BT7274_FragLifecycleProbe( string stage, entity weapon, entity projectile, float fuse )
{
#if SERVER
    try
    {
    if ( !GetConVarBool( "bot_frag_input_probe" ) || !IsValid( weapon ) ) return
    if ( weapon.GetWeaponClassName() != "mp_weapon_frag_grenade" ) return
    entity owner = weapon.GetWeaponOwner()
    if ( !IsValid( owner ) || !owner.IsPlayer() || owner.GetUID() != "0" ) return
    int projectileId = IsValid( projectile ) ? projectile.GetEncodedEHandle() : -1
    float originGap = IsValid( projectile ) ? Distance( owner.GetOrigin(), projectile.GetOrigin() ) : -1.0
    float cook = weapon.w.startChargeTime > 0.0 ? max( 0.0, Time() - weapon.w.startChargeTime ) : -1.0
    print( "BT_FRAG_STAGE schema=1 map=" + GetMapName() + " t=" + Time()
        + " stage=" + stage + " owner=" + owner.GetEncodedEHandle()
        + " weapon=" + weapon.GetEncodedEHandle() + " projectile=" + projectileId
        + " cook_s=" + cook + " fuse_s=" + fuse + " owner_gap=" + originGap )
    }
    catch ( probeError )
    {
        if ( !bt7274FragProbeState.errorLogged )
        {
            bt7274FragProbeState.errorLogged = true
            print( "BT_FRAG_PROBE_ERROR schema=1 stage=" + stage )
        }
    }
#endif
}
`;

function replaceExactlyOnce(source, needle, replacement) {
  if (source.split(needle).length !== 2)
    throw new Error('Unrecognized source signature: ' + needle.slice(0, 90));
  return source.replace(needle, replacement);
}
export function instrumentFragSource(source) {
  if (typeof source !== 'string' || source.includes('BT7274_FragLifecycleProbe('))
    throw new Error('Source is not clean or is already instrumented');
  if (!source.includes('untyped') || !source.includes('Grenade_OnWeaponTossPrep'))
    throw new Error('Expected an unmodified multiplayer _grenade.nut');
  source = replaceExactlyOnce(source, 'void function Grenade_OnWeaponTossPrep(', hook + '\nvoid function Grenade_OnWeaponTossPrep(');
  const insert = (original, addition) => { source = replaceExactlyOnce(source, original, original + '\n' + addition); };
  insert('weapon.w.startChargeTime = Time()', '    BT7274_FragLifecycleProbe( "prep", weapon, null, -1.0 )');
  insert('var result = Grenade_OnWeaponToss_( weapon, attackParams, 1.0 )',
    '    BT7274_FragLifecycleProbe( "release_callback", weapon, null, -1.0 )');
  insert('var result = Grenade_OnWeaponToss_( weapon, attackParams, 0.2 )',
    '    BT7274_FragLifecycleProbe( "cancel_drop_callback", weapon, null, -1.0 )');
  insert('entity frag = weapon.FireWeaponGrenade( attackPos, throwVelocity, angularVelocity, fuseTime, damageFlags, damageFlags, isPredicted, isLagCompensated, true )',
    '    BT7274_FragLifecycleProbe( IsValid( frag ) ? "spawn" : "spawn_null", weapon, frag, fuseTime )');
  insert('weapon.ForceReleaseFromServer() // Will eventually result in Grenade_OnWeaponToss_() or equivalent function',
    '    BT7274_FragLifecycleProbe( "forced_release_request", weapon, null, -1.0 )');
  insert('entity grenade = Grenade_Launch( weapon, weaponOwner.GetOrigin(), velocity, PROJECTILE_NOT_PREDICTED, PROJECTILE_NOT_LAG_COMPENSATED )',
    '        BT7274_FragLifecycleProbe( "death_drop", weapon, grenade, -1.0 )');
  return source;
}

function sha256(content) { return crypto.createHash('sha256').update(content).digest('hex'); }
function main(args) {
  const option = key => { const i = args.indexOf(key); return i >= 0 ? args[i + 1] : undefined; };
  const sourceName = option('--source'), outName = option('--out');
  if (!sourceName || !outName || args.length !== 4)
    throw new Error('Usage: node tools/Prepare-FragLifecycleProbe.mjs --source PATH/_grenade.nut --out PATH/_grenade.nut');
  const input = path.resolve(sourceName), output = path.resolve(outName);
  if (input === output) throw new Error('Never overwrite the original _grenade.nut');
  if (path.basename(input) !== '_grenade.nut' || path.basename(output) !== '_grenade.nut')
    throw new Error('Input and output must both be named _grenade.nut');
  const original = fs.readFileSync(input, 'utf8');
  const candidate = instrumentFragSource(original);
  fs.mkdirSync(path.dirname(output), {recursive: true});
  fs.writeFileSync(output, candidate, {flag: 'wx'}); // never replace a candidate
  console.log(JSON.stringify({source_sha256: sha256(original), candidate_sha256: sha256(candidate),
    output, note: 'Source-only candidate; do not install until isolated runtime tests.'}, null, 2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main(process.argv.slice(2));
