import test from 'node:test';
import assert from 'node:assert/strict';
import {parseBotTrialLine, parseBotTrialLog} from '../tools/Analyze-BotAITrial.mjs';

const log = (...lines) => lines.join('\n');

test('ignores arbitrary logs and never copies unrecognized text', () => {
  assert.equal(parseBotTrialLine('secret:abc'), null);
  assert.deepEqual(parseBotTrialLine('[info] BOT_FRAG_INPUT epoch=3 t=1.0 slot=2 edge=press ready=1 x=123'),
    {type: 'BOT_FRAG_INPUT', epoch: '3', t: '1.0', slot: '2', edge: 'press', ready: '1', x: '123'});
  const data = parseBotTrialLog('Authorization: Bearer secretvalue');
  assert.equal(data.cohorts.length, 0);
  assert.ok(!JSON.stringify(data).includes('secretvalue'));
});

test('pairs only within a slot and epoch; preserves orphan and truncated pulses', () => {
  const data = parseBotTrialLog(log(
    'BOT_FRAME epoch=1 map=mp_eden t=0',
    'BOT_FRAG_INPUT epoch=1 t=1 slot=2 edge=press ready=1 x=500',
    'BOT_FRAG_INPUT epoch=1 t=1.12 slot=2 edge=release held_s=0.12',
    'BOT_FRAG_INPUT epoch=1 t=2 slot=3 edge=release held_s=0.5',
    'BOT_FRAG_INPUT epoch=1 t=3 slot=2 edge=press ready=-1',
    'BOT_FRAME epoch=2 map=mp_meadow t=0',
    'BOT_FRAG_INPUT epoch=2 t=0.5 slot=2 edge=release',
  ));
  assert.equal(data.cohorts.length, 2);
  assert.equal(data.cohorts[0].map, 'mp_eden');
  assert.equal(data.cohorts[0].frag_input_presses, 2);
  assert.equal(data.cohorts[0].frag_input_releases, 2);
  assert.equal(data.cohorts[0].frag_orphan_releases, 1);
  assert.equal(data.cohorts[0].frag_unfinished_presses, 1);
  assert.equal(data.cohorts[0].frag_ready_positive_presses, 1);
  assert.equal(data.cohorts[0].input_hold_seconds.matched_edges, 1);
  assert.ok(Math.abs(data.cohorts[0].input_hold_seconds.median - 0.12) < 0.0001);
  assert.equal(data.cohorts[1].frag_orphan_releases, 1);
  assert.ok(!JSON.stringify(data).includes('x=500'));
});

test('does not claim that a command release was a throw or kill', () => {
  const data = parseBotTrialLog(log(
    'BOT_FRAG_INPUT epoch=1 t=1 slot=1 edge=press ready=1',
    'BOT_FRAG_INPUT epoch=1 t=1.8 slot=1 edge=release held_s=0.8',
    'BOT_SKILL epoch=1 t=1 slot=1 tactical=- ordnance=throw',
  ));
  const c = data.cohorts[0];
  assert.equal(c.frag_long_pulses, 1);
  assert.equal(c.skill_ordnance_requests_logged, 1);
  assert.ok(data.limits.some(x => x.includes('not a confirmed engine throw')));
  assert.equal(Object.keys(c).some(k => /(?:^|_)(?:kill|hit|cast|damage)(?:_|$)/.test(k)), false);
});

test('route cooldown association is per slot and bounded by eight seconds', () => {
  const data = parseBotTrialLog(log(
    'BOT_FRAME epoch=1 map=mp_eden t=0',
    'BOT_ROUTE_COOLDOWN epoch=1 t=1 slot=4 target=42',
    'BOT_DECISION epoch=1 t=2 slot=3 old=4 target=5 reason=pursue',
    'BOT_DECISION epoch=1 t=2 slot=4 old=42 target=5 reason=pursue',
    'BOT_DECISION epoch=1 t=2.5 slot=4 old=5 target=7 reason=pursue',
    'BOT_ROUTE_COOLDOWN epoch=1 t=4 slot=6 target=12',
    'BOT_DECISION epoch=1 t=12.1 slot=6 old=12 target=8 reason=pursue',
    'BOT_PATH epoch=1 t=3 slot=4 partial=1',
    'BOT_STALL epoch=1 t=3 slot=4 reason=no_progress',
    'BOT_STUCK epoch=1 t=3 slot=4 state=engage',
  ));
  const c = data.cohorts[0];
  assert.equal(c.route_cooldown_events, 2);
  assert.equal(c.cooldowns_followed_by_switch_within_8s, 1);
  assert.equal(c.decision_switches_logged, 4);
  assert.equal(c.path_requests_logged, 1);
  assert.equal(c.partial_paths_logged, 1);
  assert.equal(c.stall_samples_logged, 1);
  assert.equal(c.stuck_episodes_logged, 1);
});

test('bad timestamps, missing slot and duplicate presses are treated conservatively', () => {
  const data = parseBotTrialLog(log(
    'BOT_FRAG_INPUT epoch=1 t=nope slot=3 edge=press',
    'BOT_FRAG_INPUT epoch=1 t=1 edge=press',
    'BOT_FRAG_INPUT epoch=1 t=1 slot=3 edge=press',
    'BOT_FRAG_INPUT epoch=1 t=1.1 slot=3 edge=press',
    'BOT_FRAG_INPUT epoch=1 t=1.0 slot=3 edge=release',
    'BOT_FRAG_INPUT epoch=1 t=1.9 slot=3 edge=release',
  ));
  const c = data.cohorts[0];
  assert.equal(c.ignored_events_without_valid_slot_time, 2);
  assert.equal(c.frag_unfinished_presses, 1);
  assert.equal(c.frag_orphan_releases, 1);
});
