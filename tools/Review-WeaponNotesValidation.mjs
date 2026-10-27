import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {analyzeNotes} from './weapon-notes.mjs';
const dir=process.argv[2];if(!dir)throw new Error('Usage: Review-WeaponNotesValidation.mjs SESSION_DIRECTORY');
const events=fs.readFileSync(path.join(dir,'events.jsonl'),'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
const markers=events.map((e,i)=>({e,i})).filter(r=>r.e.type==='WNOTE_TEST_CASE');
assert.equal(markers.length,4,'All four synthetic validation cases must complete');
const cases=markers.map(({e,i},n)=>{
  const context=events.slice(0,i).findLast(r=>r.type==='WNOTE_CONTEXT');
  const next=markers[n+1]?.i??events.findIndex((r,j)=>j>i&&r.type==='WNOTE_TEST_COMPLETE');
  assert.ok(next>i,'Missing test completion');
  const records=events.slice(i+1,next),result=analyzeNotes([context,...records]);
  assert.equal(result.death_records,1,`${e.name}: expected one recorded death`);
  const d=result.deaths[0];
  if(e.name==='four_hits'){
    // TakeDamage injection has no engine-associated firing weapon. The HP
    // sequence is measurable, but its unknown mod stack must stay excluded.
    assert.equal(d.clean_health_episode,false);
    assert.deepEqual(d.exclusions,['unknown_mod_stack']);
    assert.equal(d.damage_events,4);
    const expected=+records.find(r=>r.type==='WNOTE_TEST_TIMING').expected_span;
    assert.ok(Math.abs(d.damage_span_s-expected)<0.001,'Damage span should match the actual injection times, including delayed scheduler ticks');
    assert.deepEqual(records.filter(r=>r.type==='WNOTE_HIT').map(r=>+r.hp),[100,75,50,25]);
    assert.deepEqual(records.filter(r=>r.type==='WNOTE_POST').map(r=>+r.hp_after),[75,50,25,0]);
  }else{
    const reason={mixed_attackers:'multiple_attackers',injured_start:'not_full_100hp_start',healing:'healing_observed'}[e.name];
    assert.equal(d.clean_health_episode,false);assert.ok(d.exclusions.includes(reason),`${e.name}: missing ${reason}`);
  }
  return {name:e.name,passed:true,damage_events:d.damage_events,damage_span_s:d.damage_span_s,qualifying:d.clean_health_episode,exclusions:d.exclusions};
});
assert.equal(events.filter(e=>e.type==='WNOTE_ERROR').length,0,'Recorder must not report callback errors');
const end=events.findIndex(e=>e.type==='WNOTE_TEST_COMPLETE');
const natural=events.slice(end+1).filter(e=>e.type==='WNOTE_HIT');
assert.ok(natural.some(e=>e.akind==='bot'&&e.vkind==='bot'),'Need real bot-vs-bot damage after the synthetic checks');
const context=events.slice(0,end).findLast(e=>e.type==='WNOTE_CONTEXT');
const combat=analyzeNotes([context,...events.slice(end+1)]);
assert.ok(combat.groups.some(g=>g.attacker_kind==='bot'&&g.victim_kind==='bot'&&g.n>0),'Real combat must produce a qualifying known-modifier full-health episode');
const report={state:'passed',metric:'first_positive_health_damage_to_death_s',cases,natural_bot_damage_events:natural.filter(e=>e.akind==='bot'&&e.vkind==='bot').length,natural_qualifying_episodes:combat.clean_health_episodes,logger_errors:0,limits:'Synthetic damage validates hooks and attribution, not weapon TTK or balance. Injected damage has an unknown modifier stack and stays excluded. Subsequent natural combat is still a controlled_validation session. No first-shot, shot-count, accuracy or visual evidence.'};
fs.writeFileSync(path.join(dir,'validation.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
