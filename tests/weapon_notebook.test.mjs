import test from 'node:test';
import assert from 'node:assert/strict';
import {idealModel} from '../tools/Build-WeaponNotebook.mjs';
const w={classname:'mp_weapon_rspn101',fire_rate_shots_s_nominal:13.5,magazine:24};
test('body breakpoints count the first hit at time zero',()=>{const r=idealModel(w,25);assert.equal(r.hits,4);assert.equal(r.ideal_first_hit_to_lethal_s,3/13.5);assert.equal(idealModel(w,100).ideal_first_hit_to_lethal_s,0);assert.equal(idealModel(w,24).hits,5);});
test('unknown inputs and reload requirements are not fabricated',()=>{for(const damage of [null,0,-1,NaN])assert.equal(idealModel(w,damage).available,false);assert.equal(idealModel({...w,magazine:2},25).available,false);});
test('nominal burst/ramp/projectile rate does not become scalar TTK',()=>{for(const classname of ['mp_weapon_hemlok','mp_weapon_esaw','mp_weapon_softball','mp_weapon_mastiff','mp_weapon_sniper'])assert.equal(idealModel({...w,classname},25).available,false);});
