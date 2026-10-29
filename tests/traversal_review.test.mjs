import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewTraversalTrial} from '../tools/Review-TraversalTrial.mjs';

test('traversal outcomes separate completion, failure, cancellation and censoring without identifiers',()=>{
  const r=reviewTraversalTrial([
    'BOT_FRAME epoch=private_epoch map=mp_eden t=0',
    'BOT_TRAVERSAL epoch=private_epoch t=1 slot=private_actor event=begin',
    'BOT_TRAVERSAL_STATE epoch=private_epoch t=1 slot=private_actor phase=approach',
    'BOT_TRAVERSAL epoch=private_epoch t=2 slot=private_actor event=complete',
    'BOT_TRAVERSAL epoch=private_epoch t=3 slot=private_actor event=begin',
    'BOT_TRAVERSAL epoch=private_epoch t=4 slot=private_actor event=failed reason=EarlyLanding',
    'BOT_TRAVERSAL epoch=private_epoch t=5 slot=private_actor event=begin',
    'BOT_TRAVERSAL epoch=private_epoch t=6 slot=private_actor event=cancel reason=replan',
    'BOT_TRAVERSAL epoch=private_epoch t=7 slot=private_actor event=begin',
  ]);
  assert.deepEqual(r.maps[0],{map:'mp_eden',begins:4,completed:1,failed:1,cancelled:1,unmatched_ends:0,censored:1,
    failure_reasons:{EarlyLanding:1},cancel_reasons:{replan:1},state_samples:{approach:1},completed_duration_s:[1]});
  assert(!JSON.stringify(r).includes('private_'));
});
test('epochs prevent joining a previous map action to a new map completion',()=>{
  const r=reviewTraversalTrial([
    'BOT_FRAME epoch=1 map=mp_eden t=0',
    'BOT_TRAVERSAL epoch=1 t=1 slot=0 event=begin',
    'BOT_FRAME epoch=2 map=mp_wargames t=0',
    'BOT_TRAVERSAL epoch=2 t=2 slot=0 event=complete',
  ]);
  assert.equal(r.maps.find(m=>m.map==='mp_eden').censored,1);
  assert.equal(r.maps.find(m=>m.map==='mp_wargames').unmatched_ends,1);
  assert.equal(r.maps.reduce((n,m)=>n+m.completed,0),0);
});
