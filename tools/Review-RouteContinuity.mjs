// Private logs in; sanitized per-phase movement aggregates out. No actor IDs exported.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {markLowProgress} from './Analyze-PlayedWeaponSession.mjs';
import {parseDiag, analyzeDiag} from './Analyze-NavDiagnostics.mjs';
const fields = line => Object.fromEntries([...line.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
export function reviewRouteContinuity(lines) {
  const phases=[],walks=[]; let phase=null,walk=null; let errors=0;
  const key=e=>`${e.epoch}|${e.t}|${e.slot}`;
  for(const line of lines) {
    if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|SAFETY_TEST_FAILED/.test(line))errors++;
    if(line.includes('ROUTE_WALK_BEGIN ')){const f=fields(line);walk={phase:f.phase,enabled:f.enabled==='true',samples:[]};walks.push(walk);}
    if(walk&&line.includes('ROUTE_WALK_SAMPLE ')){const f=fields(line);if(f.phase===walk.phase)walk.samples.push(f);}
    if(line.includes('SAFETY_TEST_PHASE ')) {
      const f=fields(line); phase={name:f.name,map:f.map,start:+f.t,players:new Map(),traces:new Map(),diag:[],segments:0,segmentSlots:new Set(),scope:new Set(),passed:false}; phases.push(phase);
    }
    if(!phase)continue;
    if(line.includes('BOT_FRAME ')){const f=fields(line);if(['0','1'].includes(f.eden_repair))phase.scope.add(+f.eden_repair);}
    if(line.includes('SAFETY_TEST_NAV_STATE '))phase.enabled=fields(line).corner==='true';
    if(line.includes('SAFETY_TEST_PHASE_PASS ')) {const f=fields(line);phase.passed=f.name===phase.name;phase.end=+f.t;phase=null;continue;}
    const m=line.match(/(?:^|\s|\])(BOT_PLAYER|BOT_TRACE|BOT_SEGMENT)\s/);
    if(m) {const e=fields(line);
      if(m[1]==='BOT_PLAYER')phase.players.set(key(e),e);
      else if(m[1]==='BOT_TRACE')phase.traces.set(key(e),e);
      else {phase.segments++;phase.segmentSlots.add(e.slot);}
    }
    const d=parseDiag(line);if(d)phase.diag.push(d);
  }
  return {schema_version:1,error_markers:errors,directed_walks:walks.map(w=>{
    const alive=w.samples.filter(s=>s.alive==='true'),dist=alive.map(s=>+s.goal_dist),heights=alive.map(s=>+s.z);
    const reached=alive.find(s=>+s.goal_dist<=100);
    return {phase:w.phase,enabled:w.enabled,samples:w.samples.length,dead_samples:w.samples.length-alive.length,
      simulation_21_verified:w.samples.length>0&&w.samples.every(s=>s.simulation==='21'),
      min_goal_distance:dist.length?Math.min(...dist):null,goal_within_100:!!reached,
      first_observed_goal_after_s:reached?(+reached.t-(+w.samples[0].t)):null,
      min_z:heights.length?Math.min(...heights):null,max_z:heights.length?Math.max(...heights):null};
  }),phases:phases.map(p=>{
    const rows=[...p.players.values()].filter(e=>e.bot==='1').map(e=>({...e,...p.traces.get(key(e))}));
    markLowProgress(rows);
    const pilots=rows.filter(e=>e.alive==='1'&&e.titan==='0'&&e.state),low=pilots.filter(e=>e.low),cells=new Map();
    const directed=walks.find(w=>w.phase===p.name),actor=directed?.samples[0]?.slot;
    const parked=new Map(),parkedSlots=new Set();
    if(actor!==undefined)for(const e of rows){
      if(e.slot===actor||e.alive!=='1'||+e.t<p.start+2)continue;
      parkedSlots.add(e.slot);
      const k=e.slot+'|'+e.id;
      if(!parked.has(k))parked.set(k,{first:e,max:0});
      const g=parked.get(k);g.max=Math.max(g.max,Math.hypot(+e.x-(+g.first.x),+e.y-(+g.first.y)));
    }
    for(const e of low){const cell=[e.x,e.y,e.z].map(v=>Math.floor(+v/128)*128).join(',');cells.set(cell,(cells.get(cell)||0)+1);}
    return {name:p.name,map:p.map,enabled:p.enabled,passed:p.passed,duration_s:p.end-p.start,
      eden_scope_values:[...p.scope].sort(),
      movement_comparison_valid:walks.length===0,
      other_bot_groups_observed:parked.size,
      other_bot_slots_observed:parkedSlots.size,
      other_bots_max_xy_excursion:parked.size?Math.max(...[...parked.values()].map(g=>g.max)):null,
      live_pilot_samples:walks.length?null:pilots.length,low_progress_samples:walks.length?null:low.length,low_progress_percent:!walks.length&&pilots.length?100*low.length/pilots.length:null,
      pending_segment_samples:p.segments,pending_segment_bot_slots:p.segmentSlots.size,
      path_bot_slots:new Set(p.diag.filter(e=>e.type==='BOT_PATH').map(e=>e.slot)).size,
      hotspots:walks.length?[]:[...cells].sort((a,b)=>b[1]-a[1]).slice(0,8).map(([cell,samples])=>({cell,samples})),navigation:analyzeDiag(p.diag)};
  }),limits:'Sequential unequal-duration smoke phases, not randomized matched rounds. Pending-segment samples prove branch execution, not traversal success. Overlapping low-progress samples are not independent incidents. Respawn/map transitions and short windows limit comparison; no human difficulty, aim or weapon conclusion.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
  for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  const bytes=fs.readFileSync(get('--log')),report=reviewRouteContinuity(bytes.toString('utf8').split(/\r?\n/));
  report.log_sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  fs.writeFileSync(get('--out'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report.phases.map(p=>({name:p.name,map:p.map,enabled:p.enabled,passed:p.passed,samples:p.live_pilot_samples,low:p.low_progress_percent,pending:p.pending_segment_samples})),null,2));
}
