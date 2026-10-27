import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const directory = new URL("../research/weapon-roles-20261026/", import.meta.url);
const reference = JSON.parse(readFileSync(new URL("reference-stats.json", directory), "utf8"));
const findings = readFileSync(new URL("FINDINGS.md", directory), "utf8");
const gaps = readFileSync(new URL("GAP-ASSESSMENT.md", directory), "utf8");
const byId = Object.fromEntries(reference.weapons.map((weapon) => [weapon.classname, weapon]));

test("covers 30 unique weapons with pinned source hashes", () => {
  assert.equal(reference.weapons.length, 30);
  assert.equal(Object.keys(byId).length, 30);
  assert.match(reference.source.commit, /^[0-9a-f]{40}$/);

  const expected = {
    AR: 5,
    SMG: 4,
    LMG: 3,
    Sniper: 3,
    Shotgun: 3,
    Grenadier: 4,
    Pistol: 4,
    "Anti-Titan": 4,
  };
  for (const [category, count] of Object.entries(expected)) {
    assert.equal(reference.weapons.filter((weapon) => weapon.category === category).length, count);
  }
  for (const weapon of reference.weapons) {
    assert.match(weapon.classname, /^mp_weapon_[a-z0-9_]+$/);
    assert.match(weapon.source_blob_sha, /^[a-f0-9]{40}$/);
    assert.ok(weapon.fire_rate_shots_s_nominal > 0);
    assert.equal(weapon.rpm_nominal, weapon.fire_rate_shots_s_nominal * 60);
    assert.ok(weapon.damage_near >= 0);
    assert.ok(weapon.damage_far >= 0);
    assert.ok(weapon.ads_in_s > 0);
    assert.ok(weapon.ads_out_s > 0);
    assert.ok(findings.includes(`| ${weapon.name} |`), `missing role row: ${weapon.name}`);
  }
});

test("does not conflate Alternator and Volt internal names", () => {
  assert.equal(byId.mp_weapon_alternator_smg.name, "Alternator");
  assert.equal(byId.mp_weapon_hemlok_smg.name, "Volt");
  assert.equal(byId.mp_weapon_alternator_smg.damage_near, 35);
  assert.equal(byId.mp_weapon_hemlok_smg.damage_near, 25);
});

test("near/far shots-to-kill comparisons don't turn into indiscriminate damage buffs", () => {
  const hits = (damage) => Math.ceil(100 / damage);
  assert.equal(hits(byId.mp_weapon_g2.damage_near), 3);
  assert.equal(hits(byId.mp_weapon_g2.damage_far), 3);
  assert.equal(hits(50), 2);
  assert.equal(hits(byId.mp_weapon_vinson.damage_near), 4);
  assert.equal(hits(byId.mp_weapon_rspn101.damage_near), 4);
  assert.equal(hits(byId.mp_weapon_car.damage_far), 8);
});

test("the ADS trial crosses stock SMG timing; remains a test, not a blanket recommendation", () => {
  const smg = byId.mp_weapon_car;
  for (const classname of ["mp_weapon_vinson", "mp_weapon_g2"]) {
    const rifle = byId[classname];
    assert.equal(rifle.ads_in_s, 0.25);
    assert.equal(rifle.ads_out_s, 0.2);
    assert.ok(rifle.ads_in_s * 0.75 < smg.ads_in_s);
    assert.ok(Math.abs(rifle.ads_out_s * 0.75 - smg.ads_out_s) < 1e-10);
  }
  assert.match(findings, /source-only/i);
  // Status after the October 26 integration: installed for the local human,
  // still explicitly distinct from a gameplay balance or hit-rate study.
  assert.match(findings, /runtime-field-tested and installed/i);
  assert.match(findings, /distinct from a gameplay balance\/hit-rate study/i);
});

test("special firing mechanisms are represented, not confused with continuous RPM", () => {
  assert.equal(byId.mp_weapon_hemlok.burst_count, 3);
  assert.equal(byId.mp_weapon_hemlok.burst_delay_s, 0.25);
  assert.equal(byId.mp_weapon_esaw.fire_rate_shots_s_nominal, 5);
  assert.equal(byId.mp_weapon_esaw.fire_rate_max_shots_s, 15);
  assert.equal(byId.mp_weapon_esaw.fire_rate_ramp_time_s, 1.75);
  assert.equal(byId.mp_weapon_pulse_lmg.charge_s, 0.5);
  assert.equal(byId.mp_weapon_pulse_lmg.burst_count, 4);
  assert.equal(byId.mp_weapon_sniper.rechamber_s, 1.6);
});

test("targeted gaps preserve the calculated 100-HP thresholds and do not assume a buff", () => {
  const ideal = (w, damage) => (Math.ceil(100 / damage) - 1) / w.fire_rate_shots_s_nominal;
  const r201 = byId.mp_weapon_rspn101;
  const flatline = byId.mp_weapon_vinson;
  const car = byId.mp_weapon_car;
  const volt = byId.mp_weapon_hemlok_smg;
  const r97 = byId.mp_weapon_r97;
  const spitfire = byId.mp_weapon_lmg;

  assert.ok(ideal(flatline, flatline.damage_near) > ideal(r201, r201.damage_near));
  assert.ok(ideal(flatline, flatline.damage_far) > ideal(r201, r201.damage_far));
  assert.ok(ideal(volt, volt.damage_near) > ideal(car, car.damage_near));
  assert.ok(ideal(volt, volt.damage_far) > ideal(car, car.damage_far));
  assert.ok(ideal(r97, r97.damage_far) < ideal(car, car.damage_far));
  assert.ok(Math.abs(ideal(spitfire, spitfire.damage_near) - ideal(r201, r201.damage_near)) < 1e-10);
  assert.equal(byId.mp_weapon_hemlok.damage_near * byId.mp_weapon_hemlok.burst_count, 99);
  assert.match(gaps, /NONE CONFIRMED/);
  assert.match(gaps, /do \*\*not\*\* issue blanket buffs/i);
  assert.match(findings, /GAP-ASSESSMENT\.md/);
});
