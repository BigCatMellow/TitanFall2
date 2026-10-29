import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import path from 'node:path';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = rel => readFileSync(path.join(root, 'BT7274.TacticalRecharge', rel), 'utf8');

test('Pulse Blade recharge uses neutral values in isolated v1.1 candidate', () => {
  const pulse = source('keyvalues/scripts/weapons/mp_weapon_grenade_sonar.txt');
  assert.match(pulse, /regen_ammo_refill_rate\s+"\*1\.0"/);
  assert.match(pulse, /regen_ammo_refill_start_delay\s+"\*1\.0"/);
  assert.doesNotMatch(pulse, /regen_ammo_refill_rate\s+"\*2\.0"/);
});

test('other five weapon tacticals retain accelerated refill and Grapple class modifier', () => {
  for (const name of ['mp_ability_cloak', 'mp_ability_heal', 'mp_ability_holopilot',
    'mp_ability_shifter', 'mp_weapon_deployable_cover']) {
    const content = source(`keyvalues/scripts/weapons/${name}.txt`);
    assert.match(content, /regen_ammo_refill_rate\s+"\*2\.0"/);
    assert.match(content, /regen_ammo_refill_start_delay\s+"\*0\.5"/);
  }
  const grapple = source('keyvalues/scripts/players/mp/pilot_mp.set');
  assert.match(grapple, /grapple_power_regen_rate\s+"\*2\.0"/);
  assert.match(grapple, /grapple_power_regen_delay\s+"\*0\.5"/);
});

test('source candidate remains explicit and limited to local human', () => {
  const mod = JSON.parse(source('mod.json'));
  assert.equal(mod.Version, '1.1.0');
  const script = source('mod/scripts/vscripts/bt7274_tactical_recharge.nut');
  assert.match(script, /NSIsPlayerLocalPlayer\( player \)/);
  assert.match(script, /ns_auth_allow_insecure/);
  assert.match(script, /mp_weapon_grenade_sonar/);
});
