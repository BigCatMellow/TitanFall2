import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'BT7274.FragDamageProbe');
const read = filename => fs.readFileSync(path.join(root, filename), 'utf8');

test('standalone frag damage mod is disabled by default and server only', () => {
  const meta = JSON.parse(read('mod.json'));
  assert.equal(meta.Name, 'BT7274.FragDamageProbe');
  assert.equal(meta.ConVars[0].Name, 'bt7274_frag_damage_probe');
  assert.equal(meta.ConVars[0].DefaultValue, '0');
  assert.equal(meta.Scripts[0].RunOn, 'SERVER && MP');
  assert.equal(meta.Scripts[0].ServerCallback.After, 'BT7274FragDamageProbe_Init');
});

test('only the frag source, bot attacker and non-Titan pilot victim are eligible', () => {
  const source = read('mod/scripts/vscripts/bt7274_frag_damage_probe.nut');
  assert.match(source, /AddDamageFinalCallback\( "player", BT7274FragDamageProbe_OnDamage \)/);
  assert.match(source, /DamageInfo_GetDamageSourceIdentifier/);
  assert.match(source, /eDamageSourceId\.mp_weapon_frag_grenade/);
  assert.match(source, /attacker\.GetUID\(\) != "0"/);
  assert.match(source, /victim\.IsTitan\(\)/);
  assert.match(source, /attacker\.IsTitan\(\)/);
  assert.match(source, /ns_auth_allow_insecure/);
});

test('damage observer never changes damage or gameplay and logs caught failures once', () => {
  const source = read('mod/scripts/vscripts/bt7274_frag_damage_probe.nut');
  assert.doesNotMatch(source, /DamageInfo_(?:Set|Scale)|TakeDamage|ForceReleaseFromServer|GrenadeExplode/);
  assert.match(source, /try\s*\{/);
  assert.match(source, /catch \( probeError \)/);
  assert.match(source, /BT_FRAG_DAMAGE_ERROR schema=1/);
  assert.match(source, /errorLogged = true/);
});
