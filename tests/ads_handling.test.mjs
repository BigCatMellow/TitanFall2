import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";

const base = new URL("../James.WeaponHandling/", import.meta.url);
const read = (path) => readFileSync(new URL(path, base), "utf8");
const manifest = JSON.parse(read("mod.json"));
const script = read("mod/scripts/vscripts/james_weapon_handling.nut");
const weaponDir = new URL("keyvalues/scripts/weapons/", base);
const weapons = ["mp_weapon_g2", "mp_weapon_vinson"];

test("handling is a separate opt-in mod, disabled on load", () => {
  assert.equal(manifest.Name, "James.WeaponHandling");
  assert.equal(manifest.ConVars.length, 1);
  assert.deepEqual(manifest.ConVars[0], {
    Name: "james_ads_trial",
    DefaultValue: "0",
  });
  assert.equal(manifest.Scripts.length, 1);
  assert.equal(manifest.Scripts[0].RunOn, "SERVER && MP");
  assert.equal(manifest.Scripts[0].ServerCallback.After, "JamesWeaponHandling_Init");
  assert.equal(manifest.Scripts[0].Path, "james_weapon_handling.nut");
});

test("only G2 and Flatline have a named ADS-only KeyValue modifier", () => {
  assert.deepEqual(readdirSync(weaponDir).sort(), weapons.map((name) => `${name}.txt`));
  for (const name of weapons) {
    const data = read(`keyvalues/scripts/weapons/${name}.txt`);
    assert.match(data, /^WeaponData\s*\{\s*Mods\s*\{\s*james_solo_ads_trial\s*\{/);
    assert.equal((data.match(/zoom_time_in\s+"\*0\.9"/g) ?? []).length, 1);
    assert.equal((data.match(/zoom_time_out\s+"\*0\.9"/g) ?? []).length, 1);
    const fields = [...data.matchAll(/^\s*(\w+)\s+"[^"\n]+"/gm)].map((match) => match[1]);
    assert.deepEqual(fields.sort(), ["zoom_time_in", "zoom_time_out"]);
  }
});

test("human solo guard and two-gun allowlist are present", () => {
  assert.match(script, /GetConVarBool\( "james_ads_trial" \)/);
  assert.match(script, /GetConVarBool\( "ns_auth_allow_insecure" \)/);
  assert.match(script, /NSIsPlayerLocalPlayer\( player \)/);
  assert.match(script, /player\.GetUID\(\) != "0"/);
  assert.match(script, /IsAlive\( player \) && !player\.IsTitan\(\) && !IsLobby\(\)/);
  assert.match(script, /array<string> supported = \["mp_weapon_vinson", "mp_weapon_g2"\]/);
});

test("modifier application is idempotent and preserves other attachment names", () => {
  assert.match(script, /AddCallback_OnPlayerRespawned/);
  assert.match(script, /AddCallback_OnPlayerInventoryChanged/);
  assert.match(script, /AddCallback_OnPlayerGetsNewPilotLoadout/);
  assert.match(script, /array<string> mods = weapon\.GetMods\(\)/);
  assert.match(script, /if \( enabled == present \) continue/);
  assert.match(script, /mods\.append\( JAMES_ADS_TRIAL_MOD \)/);
  assert.match(script, /mods\.removebyvalue\( JAMES_ADS_TRIAL_MOD \)/);
  assert.match(script, /weapon\.SetMods\( mods \)/);
});

test("named modifier stays distinct from existing reload modifier", () => {
  const reload = readFileSync(new URL("../James.WeaponReload/mod/scripts/vscripts/james_weapon_reload.nut", import.meta.url), "utf8");
  const match = script.match(/JAMES_ADS_TRIAL_MOD = "([^"]+)"/);
  const reloadMatch = reload.match(/JAMES_RELOAD_MOD = "([^"]+)"/);
  assert.ok(match && reloadMatch);
  assert.notEqual(match[1], reloadMatch[1]);
  assert.match(script, /zoom_scale=0\.90/);
});
