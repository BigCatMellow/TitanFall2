import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
const args=process.argv.slice(2),arg=k=>args[args.indexOf(k)+1];
for(const k of ['--session','--out'])if(!args.includes(k))throw new Error('Missing '+k);
const json=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const session=json(arg('--session')),state=json(path.join(session.run,'progress.json'));
assert.equal(state.state,'passed',state.failure);assert.equal(state.core,'1.31.14.0');assert.equal(state.lobby,true);
for(const phase of ['diagnostics_only','movement_proximity','roster_readback','skills_personality_height_smoke','switch_off_respawn','new_map_movement','roster_cancel'])assert.ok(state.completed.includes(phase),'Missing '+phase);
const bytes=fs.readFileSync(path.join(session.run,'raw-session.log'));
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
const rows=[],views=[];let phase=null,expectedErrors=0,errors=0;
for(const line of bytes.toString('utf8').split(/\r?\n/)){
  const match=line.match(/^(?:\[[^\]\r\n]*\]\s*)*(CAPABILITY_TEST_[A-Z_]+|BOT_[A-Z_]+|WNOTE_[A-Z_]+)(?:\s|$)/);
  if(match){const f={type:match[1],...fields(line),phase};if(f.type==='CAPABILITY_TEST_PHASE'){phase=f.name;f.phase=phase;}rows.push(f);}
  if(phase==='roster_cancel'&&line.includes('BOT_ROSTER_ERROR count=')){expectedErrors++;continue;}
  if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_ROSTER_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR/.test(line))errors++;
  const view=line.match(/eye_angles=\[([^\]]+)\] view_angles_raw=\[([^\]]+)\]/);
  if(view){const eye=view[1].split(',').map(Number),raw=view[2].split(',').map(Number);const p=eye[0]*Math.PI/180,y=eye[1]*Math.PI/180;
    const expected=[Math.cos(p)*Math.cos(y),Math.cos(p)*Math.sin(y),-Math.sin(p)];
    views.push({norm:Math.hypot(...raw),forward_error:Math.hypot(...raw.map((v,i)=>v-expected[i]))});}
}
assert.equal(errors,0,'Unexpected runtime errors');assert.equal(expectedErrors,1,'Exactly one deliberate cancellation must exercise error restoration');
const by=t=>rows.filter(r=>r.type===t);
const cancellation=by('CAPABILITY_TEST_CANCEL');assert.equal(cancellation.length,1,'Need one identified cancellation probe');
const cancelledSlot=cancellation[0].slot;
assert.ok(by('BOT_ROSTER_RESTORED').some(r=>r.phase==='roster_cancel'&&r.slot===cancelledSlot),'Missing probe cancellation restore');
assert.ok(by('CAPABILITY_TEST_LOADOUT_COPIES').length>=2,'Need independent snapshot checks on both maps');
assert.ok(by('BOT_VIEWCHECK').some(r=>r.plausible==='1'),'Hull plausibility not established');
const roster=by('BOT_ROSTER');assert.ok(roster.length>=8,'Insufficient roster readback');assert.ok(roster.every(r=>r.tactical===r.wanted||r.wanted==='keep'),'Tactical readback mismatch');
assert.equal(roster.filter(r=>r.phase==='roster_cancel'&&r.slot===cancelledSlot).length,0,'Cancelled probe assignment must never be successful');
const primaries=[...new Set(roster.map(r=>r.primary))].sort(),tacticals=[...new Set(roster.map(r=>r.tactical))].sort();
assert.equal(primaries.length,8,'All eight roster primaries required');assert.equal(tacticals.length,6,'All six requested tactical types required');
const actualWeapons=new Set(by('BOT_WEAPON').map(r=>r.weapon));assert.ok(primaries.every(g=>actualWeapons.has(g)),'A roster primary lacks native weapon observation');
const fire=by('WNOTE_FIRE');assert.ok(fire.some(r=>+r.rounds>0),'Ammo sampler produced no expenditure data');
assert.ok(by('BOT_SKILL').length>0,'No native skill requests');
const cover=by('BOT_COVER');
const report={state:'passed',run:path.basename(session.run),native_sha256:session.native_sha256,core:state.core,completed_phases:state.completed,
  unexpected_runtime_errors:errors,deliberate_cancellation_errors:expectedErrors,cancellation_restored:true,loadout_snapshot_checks:by('CAPABILITY_TEST_LOADOUT_COPIES').length,
  roster_assignments:roster.length,roster_primaries:primaries,actual_native_roster_primaries_observed:true,tactical_readbacks:tacticals,
  skill_requests:by('BOT_SKILL').length,ammo_samples:fire.length,observed_expenditure:fire.reduce((n,r)=>n+(+r.rounds||0),0),zoom_observed:fire.some(r=>r.zoom_known==='true'),
  plausible_hull_samples:by('BOT_VIEWCHECK').filter(r=>r.plausible==='1').length,
  raw_view_vector_samples:views.length,raw_view_norm_range:views.length?[Math.min(...views.map(v=>v.norm)),Math.max(...views.map(v=>v.norm))]:null,
  raw_view_forward_max_error:views.length?Math.max(...views.map(v=>v.forward_error)):null,
  cover_diagnostics:cover.length,cover_found_samples:cover.filter(r=>r.found==='1').length,
  private_log_sha256:crypto.createHash('sha256').update(bytes).digest('hex'),
  limits:'Functional isolated smoke, not a balance, fun, performance or route-success study. Ammo drops were deliberately simulated; expenditure is not accuracy. Skill requests are not confirmed casts. Crouch, route/jump and perception trials remain off. Eye/view samples describe these observed states only. Raw logs, saved state and account data stay local.'};
fs.mkdirSync(arg('--out'),{recursive:true});fs.writeFileSync(path.join(arg('--out'),'capability-validation.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
