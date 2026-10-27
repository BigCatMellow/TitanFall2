import test from 'node:test';
import assert from 'node:assert/strict';
import {markLowProgress,analyzePlayed} from '../tools/Analyze-PlayedWeaponSession.mjs';
const track=()=>Array.from({length:7},(_,i)=>({epoch:'1',slot:'1',id:'44',alive:'1',titan:'0',state:'pursue',t:String(i*2),x:'0',y:'0',commands:String(i*120),jumps:'0',yaw_travel:String(i*150)}));
test('continuous low progress distinguishes turning from jump requests',()=>{const rows=markLowProgress(track());assert.equal(rows.filter(r=>r.low).length,2);assert.equal(rows.at(-1).low_yaw_delta,750);assert.equal(rows.at(-1).low_jump_fraction,0);});
test('combat, deaths, gaps and epoch changes break low-progress windows',()=>{for(const [key,value] of [['state','engage'],['alive','0'],['id','45'],['t','5'],['epoch','2']]){const rows=track();rows[3][key]=value;assert.equal(markLowProgress(rows).filter(r=>r.low).length,0,`${key} must break continuity`);}});
const context={type:'WNOTE_CONTEXT',map:'mp_eden',mode:'normal_play',tick:'0.016667'};
const hit={type:'WNOTE_HIT',event:'1',t:'2',victim:'4002',life:'1',attacker:'8001',attacker_life:'1',akind:'human',vkind:'bot',atitan:'false',ateam:'2',vteam:'3',gun:'mp_weapon_rspn101',mods:'none',config:'on',hp:'100',max_hp:'100',range:'400',hitgroup:'1',crit_scale:'1',force:'false',avx:'0',avy:'0',vvx:'0',vvy:'0'};
const kill=[hit,{type:'WNOTE_POST',event:'1',t:'2',victim:'4002',life:'1',hp_after:'0'},{type:'WNOTE_DEATH',event:'1',t:'2',victim:'4002',life:'1'}];
const native=(epoch,active='1')=>[
`BOT_FRAME epoch=${epoch} map=mp_eden t=1.00`,
'WNOTE_CONTEXT map=mp_eden mode=normal_play',
`BOT_PLAYER epoch=${epoch} map=mp_eden t=1.00 slot=0 id=131073 bot=0 alive=1 titan=0 team=2 x=0 y=0 z=0`,
`BOT_PLAYER epoch=${epoch} map=mp_eden t=1.00 slot=1 id=65538 bot=1 alive=1 titan=0 team=3 x=0 y=0 z=0`,
`BOT_TRACE epoch=${epoch} map=mp_eden t=1.00 slot=1 target=131073 visible=1 state=engage speed=0 tz=0 jumps=0 commands=0 yaw_travel=0`,
`BOT_COMBAT epoch=${epoch} map=mp_eden t=1.00 slot=1 weapon=mp_weapon_rspn101 tactic=range_hold active=${active} blocked_steps=0`,
`BOT_PLAYER epoch=${epoch} map=mp_eden t=30.00 slot=1 id=65538 bot=1 alive=1 titan=0 x=0 y=0 z=0`,
`BOT_TRACE epoch=${epoch} map=mp_eden t=30.00 slot=1 target=131073 visible=1 state=engage speed=0 tz=0`].join('\n');
test('native target identity, active flags and post-combat trimming are respected',()=>{for(const active of ['0','1']){const r=analyzePlayed([context,...kill],native(1,active)).rounds[0];assert.equal(r.movement.live_pilot_samples,1);assert.equal(r.pressure.visible_human_engage_samples,1);assert.equal(r.movement.range_hold_samples,+active);assert.equal(r.human_pilot_kills_credited,1);}});
test('repeated maps and reused damage-event IDs retain separate round groups',()=>{const r=analyzePlayed([context,...kill,context,...kill],native(1)+'\n'+native(2));assert.equal(r.rounds.length,2);for(const round of r.rounds){assert.equal(round.human_pilot_kills_credited,1);assert.equal(round.qualifying_human_damage_groups[0].n,1);}assert.throws(()=>analyzePlayed([context,...kill],native(1).replace('BOT_FRAME epoch=1 map=mp_eden','BOT_FRAME epoch=1 map=mp_other')),/differs/);});
