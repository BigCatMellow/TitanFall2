import test from 'node:test';import assert from 'node:assert/strict';
import {reviewMoveFollowthrough} from '../research/tuning-v29-20261029/Review-MoveFollowthrough.mjs';
const pos=(t,x,extra='')=>`BOT_PLAYER epoch=1 slot=private id=private_entity bot=1 alive=1 titan=0 t=${t} x=${x} y=0 z=0 ${extra}`;
const move=t=>`BOT_FRAG_ESCAPE epoch=1 slot=private t=${t} action=move distance=100`;
test('reports actual nearby displacement without publishing native identities or counting every probe as an incident',()=>{
 const r=reviewMoveFollowthrough([pos(10,0),move(10.1),move(10.3),pos(10.5,100)]);
 assert.equal(r.move_commands,2);assert.equal(r.spaced_command_windows,1);assert.equal(r.usable_windows,1);assert.equal(r.displacement.median_units,100);assert.equal(r.windows_with_24_units_displacement,1);assert(!JSON.stringify(r).includes('private'));
});
test('death, changed entity, stale or missing snapshots cannot certify followthrough',()=>{
 for(const points of [[pos(10,0),pos(10.3,30,'alive=0'),pos(10.5,100)],[pos(10,0),pos(10.5,100,'id=replacement')],[pos(9,0),pos(10.5,100)],[pos(10,0)]]){
  const r=reviewMoveFollowthrough([...points,move(10.1)]);assert.equal(r.usable_windows,0);assert.equal(r.censored_windows,1);
 }
});
test('match window excludes pre-match and post-match commands and censors evidence beyond the boundary',()=>{
 const r=reviewMoveFollowthrough([pos(10,0),move(10.05),move(10.1),pos(10.5,100),move(11.1),pos(11.5,200)],{start:10.1,end:10.7});
 assert.equal(r.move_commands,1);assert.equal(r.usable_windows,1);
 const end=reviewMoveFollowthrough([pos(10,0),move(10.1),pos(10.5,100)],{start:10,end:10.3});
 assert.equal(end.usable_windows,0);assert.equal(end.censored_windows,1);
});
