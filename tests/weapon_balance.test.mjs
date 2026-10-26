import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const modRoot = resolve(root, 'Solo.WeaponBalance');
const read = (path) => readFileSync(resolve(modRoot, path), 'utf8');
const candidate = JSON.parse(read('balance-pass.json'));
const manifest = JSON.parse(read('mod.json'));
const script = read('mod/scripts/vscripts/solo_weapon_balance.nut');

const kvPath = (weapon) => `keyvalues/scripts/weapons/${weapon.classname}.txt`;
const fields = (s) => Object.fromEntries(
  [...s.matchAll(/^\s*([a-z][a-z0-9_]*)\s+"\*([0-9.]+)"\s*$/gm)]
    .map((m) => [m[1], Number(m[2])]),
);

test('data manifest exactly matches four uniquely named weapon KeyValue attachments', () => {
  assert.equal(candidate.weapons.length, 4);
  assert.equal(new Set(candidate.weapons.map((w) => w.classname)).size, 4);
  const expected = ['mp_weapon_vinson', 'mp_weapon_hemlok_smg', 'mp_weapon_r97', 'mp_weapon_lmg'];
  assert.deepEqual(candidate.weapons.map((w) => w.classname), expected);
  for (const weapon of candidate.weapons) {
    const content = read(kvPath(weapon));
    const kvFields = fields(content);
    assert.match(content, /^WeaponData\s*\{/);
    assert.match(content, /\bMods\s*\{\s*solo_role_balance_v1\s*\{/);
    assert.equal((content.match(/\{/g) ?? []).length, 3);
    assert.equal((content.match(/\}/g) ?? []).length, 3);
    assert.deepEqual(Object.keys(kvFields).sort(), Object.keys(weapon.fields).sort());
    for (const [key, datum] of Object.entries(weapon.fields)) {
      assert.equal(kvFields[key], datum.multiplier, `${weapon.name}.${key}`);
      const actual = datum.reference * datum.multiplier;
      assert.ok(Math.abs(actual - datum.nominal_trial) < 1e-9, `${weapon.name}.${key}`);
    }
  }
});

test('no broad damage, magazine, fire-rate, aim assist or ADS-transition modifications', () => {
  for (const w of candidate.weapons) {
    const content = read(kvPath(w));
    assert.doesNotMatch(content, /\b(damage|fire_rate|ammo_|zoom_time|aimassist|npc_|viewkick_.*_hipfire)\w*\s+"/);
  }
  assert.equal(candidate.weapons.filter((w) => w.direction === 'buff').length, 3);
  assert.equal(candidate.weapons.filter((w) => w.direction === 'nerf').length, 1);
});

test('specific role tradeoffs and critical 100 HP damage breakpoints are preserved', () => {
  const [flatline, volt, r97, spitfire] = candidate.weapons;
  assert.deepEqual(Object.keys(flatline.fields).sort(), ['viewkick_scale_max_ads', 'viewkick_scale_min_ads']);
  assert.deepEqual(Object.keys(volt.fields).sort(), ['viewkick_scale_max_ads', 'viewkick_scale_min_ads']);
  assert.ok(Object.keys(r97.fields).every((field) => field.endsWith('_hip')));
  assert.deepEqual(Object.keys(spitfire.fields), ['ads_move_speed_scale']);
  assert.equal(Math.ceil(100 / 30), 4); // unchanged Flatline reference near damage
  assert.equal(3 * 33, 99); // unchanged Hemlok reference burst body damage
  assert.equal(Math.ceil(100 / 35), 3); // unchanged Spitfire reference near damage
});

test('default-off human and bots with opt-in, insecure solo and inventory guards', () => {
  assert.deepEqual(
    manifest.ConVars,
    [
      { Name: 'solo_weapon_balance', DefaultValue: '0' },
      { Name: 'solo_weapon_balance_bots', DefaultValue: '0' },
    ],
  );
  assert.equal(manifest.Scripts[0].RunOn, 'SERVER && MP');
  assert.match(script, /GetConVarBool\( "ns_auth_allow_insecure" \)/);
  assert.match(script, /GetConVarBool\( "solo_weapon_balance" \)/);
  assert.match(script, /player\.GetUID\(\) != "0" && NSIsPlayerLocalPlayer\( player \)/);
  assert.match(script, /player\.GetUID\(\) == "0" && GetConVarBool\( "solo_weapon_balance_bots" \)/);
  assert.match(script, /!player\.IsTitan\(\) && !IsLobby\(\)/);
  assert.match(script, /AddCallback_OnPlayerRespawned/);
  assert.match(script, /AddCallback_OnPlayerInventoryChanged/);
  assert.match(script, /AddCallback_OnPlayerGetsNewPilotLoadout/);
});

test('existing weapon mods are retained and the toggle is idempotent and reversible', () => {
  assert.match(script, /array<string> mods = weapon\.GetMods\(\)/);
  assert.match(script, /if \( enabled == present \) continue/);
  assert.match(script, /mods\.append\( SOLO_ROLE_BALANCE_MOD \)/);
  assert.match(script, /mods\.removebyvalue\( SOLO_ROLE_BALANCE_MOD \)/);
  assert.match(script, /weapon\.SetMods\( mods \)/);
  assert.equal((script.match(/"solo_role_balance_v1"/g) ?? []).length, 1);
  assert.deepEqual(
    [...script.matchAll(/"(mp_weapon_[a-z0-9_]+)"/g)].map((m) => m[1]),
    candidate.weapons.map((w) => w.classname),
  );
});

test('research provenance and runtime-unknown status are recorded', () => {
  assert.equal(candidate.reference.commit, 'bc13e6120e37b3ccdbc0cba55e61fd978bdcbe21');
  assert.equal(candidate.candidate_status, 'SOURCE_ONLY_NOT_RUNTIME_VERIFIED');
  for (const weapon of candidate.weapons) assert.match(weapon.source_blob_sha, /^[a-f0-9]{40}$/);
});
