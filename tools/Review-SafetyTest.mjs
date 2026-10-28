// Read-only phase-separated safety evidence. No raw logs/actor IDs exported.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {parseNote} from './weapon-notes.mjs';
import {summarizeOrdnance} from './Analyze-PlayedCapabilities.mjs';
import {parseDiag,analyzeDiag} from './Analyze-NavDiagnostics.mjs';
const fields=line=>Object.fromEntries([...line.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
const bump=(o,k)=>{o[k]=(o[k]||0)+1;};
export function reviewSafety(lines){
  const phases=[];let current=null;let errors=0;
  for(const line of lines){
    if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_OBSERVE_ERROR|BOT_ROSTER_ERROR|WNOTE_ERROR|SAFETY_TEST_FAILED/.test(line))errors++;
    const f=fields(line);
    if(line.includes('SAFETY_TEST_PHASE ')){
      current={name:f.name,map:f.map,start_t:+f.t,end_t:null,completed:false,safety:f.safety,retarget:f.retarget,
        events:[{type:'WNOTE_CONTEXT',map:f.map,mode:'controlled_validation'}],diagnostics:[],
        commits:0,retarget_requests:0,frag_prepares:0,release_signals:0,legacy_release_signals_without_weapon:0,
        releases_by_weapon:{},uses_by_weapon:{},attack_callbacks_by_weapon:{},phase_entries:0,projectiles:new Map()};
      phases.push(current);continue;
    }
    if(line.includes('SAFETY_TEST_PHASE_PASS ')){
      if(current&&current.name===f.name){current.completed=true;current.end_t=+f.t;current=null;}continue;
    }
    if(!current)continue;
    const e=parseNote(line);if(e&&e.type!=='WNOTE_CONTEXT')current.events.push(e);
    const d=parseDiag(line);if(d)current.diagnostics.push(d);
    if(line.includes('BOT_THROW ')&&f.stage==='commit')current.commits++;
    if(line.includes('BOT_RETARGET '))current.retarget_requests++;
    if(line.includes('BOT_FRAG_PREP '))current.frag_prepares++;
    if(line.includes('BOT_OFFHAND_USED '))bump(current.uses_by_weapon,f.weapon);
    if(line.includes('BOT_OFFHAND_ATTACK '))bump(current.attack_callbacks_by_weapon,f.weapon);
    if(line.includes('BOT_PHASE ')&&f.active==='true')current.phase_entries++;
    if(line.includes('BOT_THROW_RELEASE ')){
      current.release_signals++;
      if(f.weapon)bump(current.releases_by_weapon,f.weapon);
      else current.legacy_release_signals_without_weapon++;
    }
    if(line.includes('BOT_PROJECTILE ')){
      if(!current.projectiles.has(f.projectile))current.projectiles.set(f.projectile,{samples:0,initial_speed:Math.hypot(+f.vx,+f.vy,+f.vz),min_owner_dist:Infinity,max_owner_dist:0});
      const p=current.projectiles.get(f.projectile);p.samples++;p.min_owner_dist=Math.min(p.min_owner_dist,+f.owner_dist);p.max_owner_dist=Math.max(p.max_owner_dist,+f.owner_dist);
    }
  }
  return {schema_version:1,errors,phases:phases.map(p=>{
    const ordnance=summarizeOrdnance(p.events).flatMap(r=>r.sources),navigation=analyzeDiag(p.diagnostics);
    const {events,diagnostics,projectiles,...metrics}=p;
    return {...metrics,duration_s:p.end_t===null?null:p.end_t-p.start_t,ordnance,navigation,
      owned_frag_trajectory_count:projectiles.size,owned_frag_trajectories:[...projectiles.values()]};
  }),limits:'Controlled smoke, not human balance. Natural control/candidate and manipulated-health probe are separate phases. Release signal also includes cancel/drop; offhand-use bookkeeping includes drops on death. Legacy release logs used active primary instead of the throwing offhand: weapon/age attribution from those logs is invalid. Projectile samples confirm observed owned frags but do not count all launches or show their final collision. Phase boundaries can exclude cross-boundary damage. Different durations/weapon/life mixes are not matched fight samples. Counts are not throw accuracy or first-shot TTK.'};
}
if(process.argv[1]?.endsWith('Review-SafetyTest.mjs')){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
  for(const k of ['--run','--out'])if(!args.includes(k))throw Error('Missing '+k);
  const run=get('--run'),out=get('--out');
  const bytes=fs.readFileSync(path.join(run,'raw-session.log'));
  const report=reviewSafety(bytes.toString('utf8').split(/\r?\n/));
  const meta=JSON.parse(fs.readFileSync(path.join(run,'progress.json'),'utf8').replace(/^\uFEFF/,''));
  report.runtime_state=meta.state;report.provenance={private_run:path.basename(run),log_sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
  const readJson=file=>JSON.parse(fs.readFileSync(path.join(run,file),'utf8').replace(/^\uFEFF/,''));
  if(fs.existsSync(path.join(run,'context.json')))report.context=readJson('context.json');
  if(fs.existsSync(path.join(run,'session.json'))){
    const session=readJson('session.json');
    for(const k of ['native_sha256','bridge_sha256','started'])report.provenance[k]=session[k];
  }
  fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'safety-review.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify(report.phases.map(p=>({name:p.name,completed:p.completed,duration:p.duration_s,ordnance:p.ordnance,phase_entries:p.phase_entries,retargets:p.retarget_requests})),null,2));
}
