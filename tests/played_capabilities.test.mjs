import test from 'node:test';
import assert from 'node:assert/strict';
import {summarizeOrdnance, summarizeReadiness, analyzeCapabilities} from '../tools/Analyze-PlayedCapabilities.mjs';

const context = {type: 'WNOTE_CONTEXT', map: 'mp_eden'};
const hit = {type: 'WNOTE_HIT', event: '1', victim: '20', life: '1', attacker: '10',
  akind: 'bot', vkind: 'human', atitan: 'false', ateam: '2', vteam: '3', force: 'false',
  gun: 'mp_weapon_frag_grenade', hp: '100'};
const post = {type: 'WNOTE_POST', event: '1', victim: '20', life: '1', hp_after: '0'};
const death = {type: 'WNOTE_DEATH', event: '1', victim: '20', life: '1'};

test('reused event identifiers never borrow lethal evidence from another round', () => {
  const r = summarizeOrdnance([context, hit, post, death, context, hit]);
  assert.equal(r[0].sources[0].enemy_pilot_deaths_credited, 1);
  assert.equal(r[0].sources[0].human_pilot_deaths_credited, 1);
  assert.equal(r[1].sources[0].enemy_pilot_deaths_credited, 0);
});
test('wrong victim/life or missing zero-health post cannot establish lethal credit', () => {
  for (const p of [{...post, life: '2'}, {...post, victim: '30'}, {...post, hp_after: '10'}]) {
    assert.equal(summarizeOrdnance([context, hit, p, death])[0].sources[0].enemy_pilot_deaths_credited, 0);
  }
});
test('self/friendly/forced ordnance and Titan attackers stay out of opposing kills', () => {
  for (const [h, expected] of [[{...hit, attacker: '20'}, 'self_pilot_deaths_credited'],
    [{...hit, ateam: '3'}, 'friendly_pilot_deaths_credited'], [{...hit, force: 'true'}, 'forced_callbacks']]) {
    const s = summarizeOrdnance([context, h, post, death])[0].sources[0];
    assert.equal(s.enemy_pilot_deaths_credited, 0); assert.equal(s[expected], 1);
  }
  assert.deepEqual(summarizeOrdnance([context, {...hit, atitan: 'true'}, post, death])[0].sources, []);
});
test('zero shot counters do not erase observed cooldown/resource consumption', () => {
  const r = summarizeReadiness([{tactical: 'cloak', tactical_clip: '150', tactical_cost: '200',
    tactical_ready: 'false', tactical_shots: '0'}])[0];
  assert.equal(r.below_cost_samples, 1); assert.equal(r.not_ready_samples, 1);
  assert.equal(r.nonzero_shot_counter_samples, 0); assert.equal(r.min_clip, 150);
});
test('native ability, cover and navigation observations respect epoch and round window', () => {
  const a = {rounds: [{context: 1, map: 'mp_eden', epoch: 3, telemetry_window_start: 10, telemetry_window_end: 20}]};
  const log = ['BOT_FRAME epoch=3 map=mp_eden t=10',
    'BOT_READY t=12 tactical=cloak tactical_clip=150 tactical_cost=200 tactical_ready=false tactical_shots=0',
    'BOT_SKILL epoch=3 t=13 tactical=cloak_approach ordnance=-',
    'BOT_COVER epoch=3 t=15 found=1', 'BOT_COVER epoch=3 t=21 found=1',
    'BOT_SKILL epoch=5 t=13 tactical=- ordnance=throw',
    'BOT_PATH epoch=3 t=16 partial=1 ok=1 links=1',
    'BOT_PATH epoch=5 t=16 partial=1 ok=1 links=1'].join('\n');
  const r = analyzeCapabilities([context], log, a).rounds[0];
  assert.equal(r.skill_requests.tactical_pulses, 1); assert.equal(r.skill_requests.ordnance_pulses, 0);
  assert.equal(r.cover.selected_destinations, 1); assert.equal(r.navigation.paths.requests, 1);
  assert.equal(r.readiness[0].below_cost_samples, 1);
});
