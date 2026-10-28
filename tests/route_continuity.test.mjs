import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewRouteContinuity} from '../tools/Review-RouteContinuity.mjs';
test('low-progress windows cannot cross phase boundaries; actor IDs stay private',()=>{
  const lines=[];
  for(const [name,start] of [['nav_control',0],['nav_guard',6]]) {
    lines.push(`SAFETY_TEST_PHASE map=mp_eden name=${name} t=${start}`);
    for(let t=start;t<start+6;t++) {
      lines.push(`BOT_PLAYER epoch=1 t=${t} slot=2 id=private bot=1 alive=1 titan=0 x=0 y=0 z=0`);
      lines.push(`BOT_TRACE epoch=1 t=${t} slot=2 state=pursue jumps=0 commands=${t*30} yaw_travel=0`);
    }
    lines.push(`SAFETY_TEST_NAV_STATE phase=${name} corner=${name==='nav_guard'}`);
    lines.push(`SAFETY_TEST_PHASE_PASS name=${name} t=${start+6}`);
  }
  const r=reviewRouteContinuity(lines);
  assert.deepEqual(r.phases.map(p=>p.low_progress_samples),[0,0]);
  assert.deepEqual(r.phases.map(p=>p.enabled),[false,true]);
  assert(!JSON.stringify(r).includes('private'));
});
test('incomplete phases stay incomplete and no observations stay missing',()=>{
  const r=reviewRouteContinuity(['SCRIPT ERROR','SAFETY_TEST_PHASE map=mp_eden name=nav_guard t=0',
    'BOT_SEGMENT epoch=1 t=1 slot=3 event=finish_pending']);
  assert.equal(r.error_markers,1);assert.equal(r.phases[0].passed,false);
  assert.equal(r.phases[0].low_progress_percent,null);assert.equal(r.phases[0].pending_segment_samples,1);
});
test('directed tests suppress parked-bot movement rates and verify the active mode',()=>{
  const r=reviewRouteContinuity(['ROUTE_WALK_BEGIN phase=nav_guard enabled=true',
    'ROUTE_WALK_SAMPLE phase=nav_guard t=10 alive=true x=4120 y=-272 z=128 goal_dist=5530 slot=1 simulation=21',
    'SAFETY_TEST_PHASE map=mp_eden name=nav_guard t=10',
    'BOT_PLAYER epoch=1 t=10 slot=2 id=private bot=1 alive=1 titan=0 x=0 y=0 z=0',
    'BOT_TRACE epoch=1 t=10 slot=2 state=pursue',
    'ROUTE_WALK_SAMPLE phase=nav_guard t=20 alive=true x=2500 y=-1000 z=72 goal_dist=3920 slot=1 simulation=21',
    'SAFETY_TEST_PHASE_PASS name=nav_guard t=20']);
  assert.equal(r.phases[0].low_progress_percent,null);
  assert.equal(r.phases[0].movement_comparison_valid,false);
  assert.equal(r.directed_walks[0].simulation_21_verified,true);
  assert.equal(r.directed_walks[0].min_goal_distance,3920);
  assert.equal(r.directed_walks[0].goal_within_100,false);
  assert(!JSON.stringify(r).includes('private'));
});
