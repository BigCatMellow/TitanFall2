import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
// Deliberate allowlist: the scalar model cannot represent bursts, pellets,
// spin-up, charging, projectile travel or rechambering.
const steady=new Set(['mp_weapon_rspn101','mp_weapon_rspn101_og','mp_weapon_vinson','mp_weapon_g2','mp_weapon_car','mp_weapon_alternator_smg','mp_weapon_hemlok_smg','mp_weapon_r97','mp_weapon_lmg','mp_weapon_autopistol','mp_weapon_semipistol','mp_weapon_wingman']);
export function idealModel(weapon,damage,hp=100){
  if(!steady.has(weapon.classname))return {available:false,reason:'Weapon needs a burst/pellet/ramp/charge/projectile/rechamber-specific model or has not been approved for the scalar model.'};
  const rate=weapon.fire_rate_shots_s_nominal;
  if(!Number.isFinite(damage)||damage<=0||!Number.isFinite(rate)||rate<=0||!Number.isFinite(hp)||hp<=0)return {available:false,reason:'Missing or invalid damage/rate/health.'};
  const hits=Math.ceil(hp/damage);
  if(!Number.isFinite(weapon.magazine)||hits>weapon.magazine)return {available:false,reason:'Magazine or required reload not represented.'};
  return {available:true,health:hp,body_damage:damage,hits,ideal_first_hit_to_lethal_s:(hits-1)/rate,assumptions:'Reference-only fixed body damage; full health; all hits; steady maximum cadence; no ADS/trigger delay, travel, healing, shields, damage buffs, reload or server-tick quantization.'};
}
export function buildNotebook(){
  const reference=JSON.parse(fs.readFileSync(path.join(root,'research/weapon-roles-20261026/reference-stats.json')));
  const runtime=JSON.parse(fs.readFileSync(path.join(root,'Notes/candidates/weapons-v19-20261026/runtime-review.json')));
  const weapons=reference.weapons.map(w=>({name:w.name,classname:w.classname,category:w.category,reference:w,ideal_body_models:Object.fromEntries(['near','far','very_far'].map(b=>[b,idealModel(w,w['damage_'+b])])),runtime_checks:runtime.weapon_checks.filter(v=>v.gun===w.classname),runtime_role_fields:runtime.weapon_values.filter(v=>v.gun===w.classname),observed_combat_metrics:null}));
  const out=path.join(root,'Notes/weapon-notebook');fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'catalog.json'),JSON.stringify({schema_version:1,source:reference.source,runtime_evidence:'Notes/candidates/weapons-v19-20261026/runtime-review.json',runtime_build:'weapons-v19-candidate',runtime_native_sha256:'9E8809146E17399B1CE572A5B479846C9A53633C48B7154A02159F47B19A4D6D',limits:'Reference values are not a dump of the installed game. Models are conditional estimates, not measured TTK. Observed combat is stored separately per session; null means not yet measured here.',weapons},null,2)+'\n');
  const fmt=m=>m.available?`${m.hits} hits / ${(m.ideal_first_hit_to_lethal_s*1000).toFixed(1)} ms`:'Needs dedicated model';
  const rows=weapons.map(w=>`| ${w.name} | ${w.reference.damage_near??'?'} / ${w.reference.damage_far??'?'} / ${w.reference.damage_very_far??'?'} | ${w.reference.rpm_nominal??'?'} | ${w.reference.magazine??'?'} | ${fmt(w.ideal_body_models.near)} | ${fmt(w.ideal_body_models.far)} |`);
  fs.writeFileSync(path.join(out,'REFERENCE.md'),['# Weapon reference notebook','','Generated with `node tools/Build-WeaponNotebook.mjs`; full fields, source revision, assumptions and validated role-field checks are in [catalog.json](catalog.json).','','These are pinned reference facts and ideal fixed-damage estimates for a 100-HP body target. They are **not measured current-game TTK**. Near/far columns use each gun\'s own damage bands; they are not a comparison at one shared distance. Time starts at the first hit, omitting acquisition, ADS, missed shots, travel and tick quantization. Null/inherited fields are unknown, not zero.','','| Weapon | Reference damage near/far/very far | Nominal RPM | Magazine | Ideal near | Ideal far |','|---|---:|---:|---:|---|---|',...rows,'','Burst/charge/pellet/ramp/projectile/rechamber weapons need dedicated models. The allowlist is intentionally limited. Current changes to handling and reload do not establish better damage or observed TTK. [Methods and recording](README.md).',''].join('\n'));
  return weapons;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(`Built ${buildNotebook().length} reference weapon records.`);
