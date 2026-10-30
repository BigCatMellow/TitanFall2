import fs from 'node:fs';import test from 'node:test';import assert from 'node:assert/strict';
import {reviewTuningRound} from '../tools/Review-TuningRound.mjs';import {reviewIntegrationRound} from '../tools/Review-IntegrationRound.mjs';
const d=JSON.parse(fs.readFileSync(new URL('../automation/tuning-v29-cells.json',import.meta.url)));
const round=cell=>['WNOTE_CONTEXT schema=1 map=mp_test mode=controlled_validation config=test','MAP_SURVEY_BEGIN map=mp_test goal=20 bots=16 imc=8 militia=8 observer_alive=0',
 'MAP_SURVEY_TUNING t=10 cell='+cell+' '+Object.entries({...d.base,...d.cells[cell]}).map(([k,v])=>k+'='+v).join(' '),
 'BOT_FRAG_ESCAPE t=11 slot=private action=move distance=120 probe_us=9',
 'BOT_CLEARANCE_PROBE t=11 slot=private fit=Some(DuckOnly) probe_us=7',
 'BT_FRAG_AWARE_SAMPLE t=11 owner=private projectile=private gx=1 gy=2 gz=3',
 'BOT_FRAG_ESCAPE t=9 slot=private action=move distance=120 probe_us=10000',
 'MAP_SURVEY_RESULT map=mp_test valid=true elapsed=12 imc=20 militia=15'];
test('tuning cells remain distinct, aggregate only in-window commands/probes without identifiers',()=>{
 for(const cell of Object.keys(d.cells)){let a=round(cell),r=reviewTuningRound(a);assert.equal(r.cohort,'tuning_v29');assert.equal(r.cell,cell);assert.equal(r.tuning.escape.move_samples,1);assert.equal(r.tuning.escape.probe_us.p95_us,9);assert.equal(r.tuning.clearance.probes,1);assert.equal(r.tuning.awareness_samples,1);assert(!JSON.stringify(r).includes('private'));assert.throws(()=>reviewIntegrationRound(a));}
});
test('tuning readback must keep strict frag/height trials off and preserve clockless faults',()=>{
 assert.throws(()=>reviewTuningRound(round('escape').map(l=>l.replace('frag=0','frag=1'))));
 let a=round('baseline');a.splice(3,0,'BT_FRAG_AWARE_ERROR reason=test');assert.equal(reviewTuningRound(a).error_markers,1);
});
test('nearby escape restarts and completed command spans are counted without publishing actor identities',()=>{
 const a=round('escape').filter(l=>!l.includes('BOT_FRAG_ESCAPE '));a.splice(3,0,
  'BOT_FRAG_ESCAPE epoch=1 t=11 slot=private action=move distance=100',
  'BOT_FRAG_ESCAPE epoch=1 t=11.2 slot=private action=move distance=110',
  'BOT_FRAG_ESCAPE epoch=1 t=11.3 slot=private action=release distance=-1',
  'BOT_FRAG_ESCAPE epoch=1 t=11.4 slot=private action=move distance=120',
  'BOT_FRAG_ESCAPE epoch=1 t=12 slot=private action=release distance=-1');
 const r=reviewTuningRound(a);assert.equal(r.tuning.escape.nearby_restarts_within_300ms,1);
 assert.equal(r.tuning.escape.completed_command_episodes.n,2);
 assert(Math.abs(r.tuning.escape.completed_command_episodes.median_s-0.6)<1e-6);
 assert(!JSON.stringify(r).includes('private'));
});
