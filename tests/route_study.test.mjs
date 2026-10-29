import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewRouteStudy} from '../tools/Review-RouteStudy.mjs';
const begin=['WNOTE_CONTEXT schema=1 map=mp_test mode=controlled_validation config=test',
  'MAP_SURVEY_BEGIN map=mp_test goal=50 bots=16 imc=8 militia=8 observer_alive=0',
  'MAP_SURVEY_ROUTE t=10 variant=1 continuity=1 detour=1 eden=1 measurements=1 safety=false retarget=false'];
const end='MAP_SURVEY_RESULT map=mp_test valid=true elapsed=12 imc=50 militia=40';
test('round boundaries and projectile joins prevent false outcome/weapon denominators',()=>{
  const r=reviewRouteStudy([...begin,
    'BWEAPON_WINDOW t=12 start=9 gun=mp_weapon_car samples=20 attacks=99 shots_parameter=99 ammo_decreases=99 clip_increases=0 owner=private',
    'BWEAPON_WINDOW t=12 start=10 gun=mp_weapon_car samples=20 attacks=3 shots_parameter=3 ammo_decreases=2 clip_increases=1 owner=private',
    'BFRAG_SPAWN t=11 projectile=private_frag owner=private',
    'BFRAG_KILL t=12 projectile=private_frag self=true friendly=false',
    'BFRAG_KILL t=13 projectile=unmatched self=false friendly=false',end]);
  assert.equal(r.weapons[0].attack_callbacks,3);assert.equal(r.weapons[0].ammo_decrease_proxy,2);
  assert.equal(r.weapon_windows_excluded_at_boundaries,1);assert.equal(r.frag.observed_projectiles,1);
  assert.equal(r.frag.self_kill_projectile_fraction,1);assert.equal(r.frag.unmatched_kill_callbacks,1);
  assert.equal(r.frag.matched_enemy_deaths,0);assert(!JSON.stringify(r).includes('private'));
});
test('incomplete, duplicated and mismatched variants cannot enter paired comparisons',()=>{
  assert.throws(()=>reviewRouteStudy(begin));
  assert.throws(()=>reviewRouteStudy([...begin,...begin,end]));
  assert.throws(()=>reviewRouteStudy([begin[0],begin[1],begin[2].replace('detour=1','detour=0'),end]));
});
