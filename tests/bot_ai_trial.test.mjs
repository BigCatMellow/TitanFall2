import test from 'node:test';
import assert from 'node:assert/strict';
import {parseBotTrialLine, parseBotTrialLog, cornerClass} from '../tools/Analyze-BotAITrial.mjs';

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

test('clearance diagnostics count command transitions, not successful passages', () => {
  const data = parseBotTrialLog(log(
    'BOT_FRAME epoch=8 map=mp_eden t=0',
    'BOT_CLEARANCE epoch=8 t=1 slot=3 intent=Duck probes=2 starts=1 x=100',
    'BOT_CLEARANCE epoch=8 t=1.5 slot=3 intent=Normal successes=1 x=120',
    'BOT_CLEARANCE epoch=8 t=2 slot=4 intent=Duck starts=1',
    'BOT_CLEARANCE epoch=8 t=2.6 slot=4 intent=Failed failures=1',
    'BOT_CLEARANCE epoch=8 t=nope slot=7 intent=Duck',
  ));
  const c = data.cohorts[0];
  assert.equal(c.clearance_duck_starts_logged, 2);
  assert.equal(c.clearance_releases_logged, 1);
  assert.equal(c.clearance_failed_attempts_logged, 1);
  assert.equal(c.ignored_events_without_valid_slot_time, 1);
  assert.ok(data.limits.some(line => line.includes('not player animation')));
  assert.ok(!JSON.stringify(data).includes('x=120'));
  assert.ok(!Object.keys(c).some(key => key.includes('successful_passages')));
});

test('native corner classes retain unknown jump codes without assigning movement', () => {
  assert.equal(cornerClass(0, 0), 'ordinary_candidate');
  assert.equal(cornerClass(1, 0), 'ordinary_candidate');
  assert.equal(cornerClass(4, 0), 'offmesh_flag');
  assert.equal(cornerClass(5, 7), 'offmesh_flag');
  assert.equal(cornerClass(0, 7), 'coded_jump');
  assert.equal(cornerClass(2, 255), 'unknown_jump');
  assert.equal(cornerClass(16, 0), 'unknown_flags');
  assert.equal(cornerClass(-1, -1), 'missing');
  assert.equal(cornerClass(0, NaN), 'missing');
});

test('corner and stall histograms only expose raw code pairs, no positions', () => {
  const data = parseBotTrialLog(log(
    'BOT_FRAME epoch=11 map=mp_eden t=1',
    'BOT_CORNER epoch=11 t=1 slot=3 flags=4 jump=7 x=123 y=200',
    'BOT_CORNER epoch=11 t=2 slot=3 flags=4 jump=7 x=456 y=200',
    'BOT_CORNER epoch=11 t=3 slot=3 flags=0 jump=0 x=450',
    'BOT_CORNER epoch=11 t=4 slot=3 flags=-1 jump=-1',
    'BOT_CORNER epoch=11 t=5 slot=3 flags=0 jump=255',
    'BOT_STALL epoch=11 t=5 slot=3 reason=no_progress corner_flags=4 corner_jump=7 x=456',
    'BOT_STALL epoch=11 t=6 slot=3 reason=waypoint_timeout corner_flags=-1 corner_jump=-1',
  ));
  const c = data.cohorts[0];
  assert.equal(c.corners_by_class.offmesh_flag, 2);
  assert.equal(c.corners_by_class.ordinary_candidate, 1);
  assert.equal(c.corners_by_class.unknown_jump, 1);
  assert.equal(c.corners_by_class.missing, 1);
  assert.equal(c.stall_samples_by_corner_class.offmesh_flag, 1);
  assert.equal(c.stall_samples_by_corner_class.missing, 1);
  assert.deepEqual(c.raw_corner_codes.find(x => x.flags === 4 && x.jump === 7), {flags: 4, jump: 7, count: 2});
  assert.deepEqual(c.raw_stalled_corner_codes, [{flags: 4, jump: 7, count: 1}]);
  assert.ok(!JSON.stringify(data).includes('x=456'));
  assert.ok(data.limits.some(x => x.includes('not a per-link failure rate')));
});
