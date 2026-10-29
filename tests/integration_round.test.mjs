import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {reviewIntegrationRound} from '../tools/Review-IntegrationRound.mjs';
import {reviewRouteStudy} from '../tools/Review-RouteStudy.mjs';
const config=JSON.parse(fs.readFileSync(new URL('../automation/integration-v28-cells.json',import.meta.url)));
function log(cell='baseline'){
 const settings={...config.base,...config.cells[cell]};
 return ['WNOTE_CONTEXT schema=1 map=mp_test mode=controlled_validation config=test','MAP_SURVEY_BEGIN map=mp_test goal=50 bots=16 imc=8 militia=8 observer_alive=0',
 'MAP_SURVEY_INTEGRATION t=10 cell='+cell+' '+Object.entries(settings).map(([k,v])=>k+'='+v).join(' '),
 'BWEAPON_WINDOW t=12 start=10 gun=mp_weapon_car samples=20 attacks=3 shots_parameter=3 ammo_decreases=3 clip_increases=0 owner=private',
 'MAP_SURVEY_RESULT map=mp_test valid=true elapsed=12 imc=50 militia=40'];
}
test('each independent cell is explicit and cannot masquerade as frozen v24 data',()=>{
 for(const cell of Object.keys(config.cells)){const lines=log(cell);const r=reviewIntegrationRound(lines);assert.equal(r.cell,cell);assert.equal(r.cohort,'integration_v28');assert.equal(r.weapons[0].attack_callbacks,3);assert(!JSON.stringify(r).includes('private'));assert.throws(()=>reviewRouteStudy(lines));}
});
test('unknown/missing/wrong integration settings and incomplete rounds fail closed',()=>{
 const a=log('frag');assert.throws(()=>reviewIntegrationRound(a.map(l=>l.replace('frag=1','frag=0'))));
 assert.throws(()=>reviewIntegrationRound(a.map(l=>l.replace('cell=frag','cell=unknown'))));
 assert.throws(()=>reviewIntegrationRound(a.map(l=>l.replace('coordination=1',''))));
 assert.throws(()=>reviewIntegrationRound(a.slice(0,-1)));
});
