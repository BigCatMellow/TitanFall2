import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewFragExposure} from '../tools/Review-FragExposure.mjs';
const begin=['WNOTE_CONTEXT schema=1 map=mp_test mode=controlled_validation config=test','MAP_SURVEY_BEGIN map=mp_test goal=50 bots=16 imc=8 militia=8 observer_alive=0','MAP_SURVEY_ROUTE t=10 variant=0 continuity=0 detour=0 eden=1 measurements=1 safety=false retarget=false'];
const end='MAP_SURVEY_RESULT map=mp_test valid=true elapsed=12 imc=50 militia=40';
test('outcomes use observed in-window projectiles, latest preceding samples, no identifiers',()=>{
  const r=reviewFragExposure([...begin,
    'BFRAG_SPAWN t=9 projectile=outside speed=0 owner_dist=1',
    'BFRAG_SPAWN t=11 projectile=private_projectile owner=private_actor speed=100 owner_dist=20',
    'BFRAG_SAMPLE t=12.5 projectile=private_projectile owner_dist=80',
    'BFRAG_SAMPLE t=12.9 projectile=private_projectile owner_dist=100',
    'BFRAG_SAMPLE t=13.1 projectile=private_projectile owner_dist=900',
    'BFRAG_KILL t=13 projectile=private_projectile self=true friendly=false',
    'BFRAG_KILL t=13 projectile=private_projectile self=false friendly=false',
    'BFRAG_KILL t=13 projectile=outside self=true friendly=false',end]);
  assert.equal(r.observed_projectiles,1);assert.equal(r.unmatched_kill_callbacks,1);
  const g=r.groups[0];assert.equal(g.projectiles_with_self_kill,1);assert.equal(g.projectiles_with_enemy_kill,1);
  assert.equal(g.median_first_seen_to_self_kill_s,2);assert.equal(g.median_last_owner_distance_before_self_kill,100);
  assert(!JSON.stringify(r).includes('private_'));
});
test('old samples stay missing and duplicate spawns/runtime errors fail closed',()=>{
  const spawn='BFRAG_SPAWN t=11 projectile=x speed=900 owner_dist=40';
  const r=reviewFragExposure([...begin,spawn,'BFRAG_SAMPLE t=11 projectile=x owner_dist=80','BFRAG_KILL t=13 projectile=x self=true friendly=false',end]);
  assert.equal(r.groups[0].self_kills_with_recent_sample,0);assert.equal(r.groups[0].median_last_owner_distance_before_self_kill,null);
  assert.throws(()=>reviewFragExposure([...begin,spawn,spawn,end]));
  assert.throws(()=>reviewFragExposure([...begin,'BOT_MEASURE_ERROR bad',end]));
});
