import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewSafety} from '../tools/Review-SafetyTest.mjs';
test('phase boundaries separate control, candidate and manipulated-health observations',()=>{
  const r=reviewSafety(['SAFETY_TEST_PHASE map=mp_eden name=control t=1 safety=false retarget=false',
    'BOT_THROW_RELEASE t=2 active=mp_weapon_car prep_age=2','SAFETY_TEST_PHASE_PASS name=control t=3',
    'BOT_PHASE active=true','SAFETY_TEST_PHASE map=mp_eden name=probe t=4 safety=true retarget=true',
    'BOT_PHASE active=true','BOT_THROW_RELEASE weapon=mp_weapon_frag_grenade prep_age=0.5',
    'SAFETY_TEST_PHASE_PASS name=probe t=5']);
  assert.equal(r.phases[0].phase_entries,0);assert.equal(r.phases[0].legacy_release_signals_without_weapon,1);
  assert.deepEqual(r.phases[0].releases_by_weapon,{});assert.equal(r.phases[1].phase_entries,1);
  assert.equal(r.phases[1].releases_by_weapon.mp_weapon_frag_grenade,1);assert.equal(r.phases[1].duration_s,1);
});
test('partial phases stay incomplete and projectile samples remain distinct from launch counts',()=>{
  const r=reviewSafety(['SAFETY_TEST_PHASE map=mp_eden name=trial t=1 safety=true retarget=true',
    'BOT_PROJECTILE projectile=10 vx=3 vy=4 vz=0 owner_dist=100','BOT_PROJECTILE projectile=10 vx=0 vy=0 vz=0 owner_dist=60']);
  assert.equal(r.phases[0].completed,false);assert.equal(r.phases[0].owned_frag_trajectory_count,1);
  assert.equal(r.phases[0].owned_frag_trajectories[0].samples,2);assert.equal(r.phases[0].owned_frag_trajectories[0].initial_speed,5);
});
