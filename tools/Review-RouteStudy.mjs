// Sanitized aggregates only; raw actor/projectile identifiers stay local.
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseDiag,analyzeDiag} from './Analyze-NavDiagnostics.mjs';
import {markLowProgress} from './Analyze-PlayedWeaponSession.mjs';
import {parseNote,analyzeNotes} from './weapon-notes.mjs';
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
const integrationDefinition=JSON.parse(fs.readFileSync(new URL('../automation/integration-v28-cells.json',import.meta.url),'utf8'));
export function reviewRouteStudy(lines,{integration=false}={}){
  let active=false,begins=0,header,variant,result,context,errors=0;
  const players=new Map(),traces=new Map(),diag=[],notes=[],windows=[],spawns=[],kills=[],samples=[];
  const key=e=>`${e.epoch}|${e.t}|${e.slot}`;
  for(const line of lines){
    if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_MEASURE_ERROR|BT_FRAG_DAMAGE_ERROR|BT_FRAG_PROBE_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR/.test(line))errors++;
    const note=parseNote(line);if(note?.type==='WNOTE_CONTEXT')context=note;
    if(line.includes('MAP_SURVEY_BEGIN ')){active=true;begins++;header=fields(line);continue;}
    if(line.includes('MAP_SURVEY_ROUTE '))variant=fields(line);
    if(integration&&line.includes('MAP_SURVEY_INTEGRATION '))variant=fields(line);
    if(line.includes('MAP_SURVEY_RESULT ')){result=fields(line);active=false;}
    if(note&&note.type!=='WNOTE_CONTEXT')notes.push(note);
    if(line.includes('BWEAPON_WINDOW '))windows.push(fields(line));
    if(line.includes('BFRAG_SPAWN '))spawns.push(fields(line));
    if(line.includes('BFRAG_KILL '))kills.push(fields(line));
    if(line.includes('BFRAG_SAMPLE '))samples.push(fields(line));
    if(!active)continue;
    const d=parseDiag(line);if(d)diag.push(d);
    const m=line.match(/(?:^|\s|\])(BOT_PLAYER|BOT_TRACE)\s/);
    if(m){const e=fields(line);(m[1]==='BOT_PLAYER'?players:traces).set(key(e),e);}
  }
  if(begins!==1||result?.valid!=='true'||!variant)throw Error('Require one completed study round');
  if(integration){
    if(!Object.hasOwn(integrationDefinition.cells,variant.cell))throw Error('Unknown integration cell');
    const expected={...integrationDefinition.base,...integrationDefinition.cells[variant.cell]};
    for(const [key,value] of Object.entries(expected))if(variant[key]!==String(value))throw Error('Unexpected integration settings: '+key);
  }else{
    if(!['0','1'].includes(variant.variant)||variant.continuity!==variant.variant||variant.detour!==variant.variant||variant.eden!=='1'||variant.measurements!=='1'||variant.safety!=='false'||variant.retarget!=='false')throw Error('Unexpected experimental settings');
  }
  const start=+variant.t,end=start+(+result.elapsed),inside=e=>+e.t>=start&&+e.t<=end+0.1;
  if(!Number.isFinite(start)||!Number.isFinite(end)||!context)throw Error('Missing time/context boundary');
  if(header.map!==result.map||context.map!==result.map)throw Error('Map context mismatch');
  const rows=[...players.values()].filter(p=>p.bot==='1').map(p=>({...p,...traces.get(key(p))}));
  markLowProgress(rows);
  const pilots=rows.filter(p=>p.alive==='1'&&p.titan==='0'&&p.state),low=pilots.filter(p=>p.low);
  const gunWindows=windows.filter(w=>+w.start>=start&&+w.t<=end+0.1),guns=new Map();
  for(const w of gunWindows){
    if(!guns.has(w.gun))guns.set(w.gun,{gun:w.gun,windows:0,samples:0,attack_callbacks:0,shots_parameter_sum:0,ammo_decrease_proxy:0,clip_increases:0});
    const g=guns.get(w.gun);g.windows++;g.samples+=+w.samples;g.attack_callbacks+=+w.attacks;
    g.shots_parameter_sum+=+w.shots_parameter;g.ammo_decrease_proxy+=+w.ammo_decreases;g.clip_increases+=+w.clip_increases;
  }
  const observed=new Map(spawns.filter(inside).map(p=>[p.projectile,p]));
  const fragKills=kills.filter(inside),joined=fragKills.filter(k=>observed.has(k.projectile));
  const self=joined.filter(k=>k.self==='true'),enemy=joined.filter(k=>k.self!=='true'&&k.friendly!=='true');
  const selfIds=new Set(self.map(k=>k.projectile)),enemyIds=new Set(enemy.map(k=>k.projectile));
  const measured=analyzeNotes([context,...notes.filter(inside)]);
  return {schema_version:1,map:result.map,...(integration?{cohort:'integration_v28',cell:variant.cell,settings:Object.fromEntries(Object.keys(integrationDefinition.base).map(k=>[k,+variant[k]]))}:{variant:+variant.variant}),goal:+header.goal,duration_s:+result.elapsed,
    error_markers:errors,score:{imc:+result.imc,militia:+result.militia},live_pilot_samples:pilots.length,
    low_progress_samples:low.length,low_progress_percent:pilots.length?100*low.length/pilots.length:null,
    navigation:analyzeDiag(diag),weapons:[...guns.values()],weapon_windows_excluded_at_boundaries:windows.length-gunWindows.length,
    frag:{observed_projectiles:observed.size,pilot_kill_callbacks:fragKills.length,matched_self_deaths:self.length,
      matched_enemy_deaths:enemy.length,projectiles_with_self_kill:selfIds.size,projectiles_with_enemy_kill:enemyIds.size,
      unmatched_kill_callbacks:fragKills.length-joined.length,
      self_kill_projectile_fraction:observed.size?selfIds.size/observed.size:null,
      enemy_kill_projectile_fraction:observed.size?enemyIds.size/observed.size:null,
      observed_near_end:new Set(samples.filter(s=>observed.has(s.projectile)&&+s.t>=end-0.6&&+s.t<=end+0.1).map(s=>s.projectile)).size},
    damage_notes:{death_records:measured.death_records,qualifying_episodes:measured.clean_health_episodes,groups:measured.groups},
    limits:'Fresh-process bot-only Full cohort. Navigation windows overlap and are not independent failures. The global continuity trial can affect pilot/Titan routing, while the low-progress metric here covers pilots only. Weapon callbacks/shot parameters and sampled magazine decreases remain separate proxies, not validated discharges or accuracy. Refills and boundary windows can hide expenditure. Frags are observed valid-owner pilot projectiles; very short-lived/missed/pre-window entities and invalid inflictors remain unmatched. Outcome fractions can overlap and near-end projectiles are censored. No human difficulty or randomized causal balance claim.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
  for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  const bytes=fs.readFileSync(get('--log')),r=reviewRouteStudy(bytes.toString('utf8').split(/\r?\n/));
  r.log_sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  fs.writeFileSync(get('--out'),JSON.stringify(r,null,2)+'\n');
  console.log(JSON.stringify({map:r.map,variant:r.variant,low:r.low_progress_percent,frags:r.frag.observed_projectiles,weapon_windows:r.weapons.reduce((n,g)=>n+g.windows,0),errors:r.error_markers}));
}
