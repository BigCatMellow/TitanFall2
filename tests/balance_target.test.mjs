import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {summarize, TARGET} from '../tools/Check-BalanceTarget.mjs';

test('published played session is far above the 3:1 target', () => {
  const a = JSON.parse(fs.readFileSync(new URL('../research/played-weapons-20261026/analysis.json', import.meta.url), 'utf8'));
  const s = summarize([a]);
  assert.equal(s.kills, 87); assert.equal(s.deaths, 9);
  assert.equal(s.verdict, 'bots too easy');
  const traffic = s.maps.find(m => m.map === 'mp_lf_traffic');
  assert.equal(traffic.verdict, 'too few deaths to judge');
  assert.equal(s.maps.find(m => m.map === 'mp_wargames').verdict, 'bots too easy');
  assert.ok(s.bot_damage_samples >= 20);
});

test('target band classifies easy, on-target and hard outcomes', () => {
  const round = (k, d) => ({rounds: [{map: 'm', human_pilot_kills_credited: k, human_pilot_deaths_recorded: d, telemetry_window_start: 0, telemetry_window_end: 600}]});
  assert.equal(summarize([round(30, 10)]).verdict, 'on target');
  assert.equal(summarize([round(40, 10)]).verdict, 'bots too easy');
  assert.equal(summarize([round(20, 10)]).verdict, 'bots too hard');
  assert.equal(summarize([round(5, 1)]).verdict, 'too few deaths to judge');
  assert.equal(summarize([round(30, 10)]).maps[0].kills_per_10min, 30);
  assert.equal(TARGET.kd, 3);
});
