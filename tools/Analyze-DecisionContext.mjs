// Offline only: consumes published v16 snapshots; never launches or edits the game.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const EPS = 0.00001;
const GAP = 2.1;
const numeric = new Set(('epoch t slot id team bot alive titan hp x y z target visible tx ty tz '
  + 'path_requests recoveries').split(' '));
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
const hashText = text => hash(text.replaceAll('\r\n', '\n'));
const median = values => {
  const a = [...values].sort((x, y) => x - y);
  return a.length ? (a[Math.floor((a.length - 1) / 2)] + a[Math.floor(a.length / 2)]) / 2 : null;
};
const pct = (n, d) => d ? Math.round(10000 * n / d) / 100 : null;
const xy = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

function csv(text) {
  const records = [], row = [];
  let value = '', quoted = false;
  text = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') { value += '"'; i++; }
      else quoted = !quoted;
    } else if (!quoted && (c === ',' || c === '\n' || c === '\r')) {
      row.push(value); value = '';
      if (c !== ',') {
        records.push([...row]); row.length = 0;
        if (c === '\r' && text[i + 1] === '\n') i++;
      }
    } else value += c;
  }
  if (quoted) throw new Error('Unclosed CSV quote');
  if (value.length || row.length) { row.push(value); records.push([...row]); }
  const header = records.shift();
  return records.filter(r => r.length > 1).map(r => {
    assert.equal(r.length, header.length, 'CSV column count');
    return Object.fromEntries(header.map((key, i) => {
      const v = numeric.has(key) ? Number(r[i]) : r[i];
      if (numeric.has(key)) assert.ok(r[i] !== '' && Number.isFinite(v), `Invalid ${key}`);
      return [key, v];
    }));
  });
}

function csvText(rows, columns) {
  const cell = v => '"' + String(v ?? '').replaceAll('"', '""') + '"';
  return [columns.map(cell).join(','), ...rows.map(r => columns.map(k => cell(r[k])).join(','))].join('\n') + '\n';
}

function groups(rows, key) {
  const result = new Map();
  for (const r of rows) {
    const k = key(r);
    if (!result.has(k)) result.set(k, []);
    result.get(k).push(r);
  }
  return result;
}

const livePilot = r => r.bot === 1 && r.alive === 1 && r.titan === 0;
const highEngage = r => livePilot(r) && r.state === 'engage' && r.visible === 1
  && r.target >= 0 && r.tz - r.z > 5000;

function overheadBursts(rows) {
  // All actor types supply target coordinates; only live pilot visible engagement
  // can mark a high frame. Deduplicate different bots viewing the same entity.
  const actorsByTime = groups(rows, r => r.t);
  const byTarget = groups(rows.filter(r => r.bot === 1 && r.alive === 1 && r.target >= 0), r => r.target);
  const bursts = [];
  for (const [target, observations] of byTarget) {
    const frames = [...groups(observations, r => r.t)].map(([t, a]) => {
      const high = a.filter(highEngage);
      const actors = (actorsByTime.get(t) ?? []).filter(r => r.id === target && r.alive === 1);
      return { t, z: median(a.map(r => r.tz)), spread: Math.max(...a.map(r => r.tz)) - Math.min(...a.map(r => r.tz)),
        high, actor: actors.some(r => r.titan === 1) ? 'player_titan' : actors.length ? 'player_pilot' : 'not_in_player_frame' };
    }).sort((a, b) => a.t - b.t);
    let run = [];
    function finish(next) {
      if (!run.length) return;
      const first = run[0], last = run.at(-1);
      const adjacentNext = next && next.t - last.t <= GAP ? next : null;
      const follow = adjacentNext ? [...run, adjacentNext] : run;
      const steps = follow.slice(1).map((f, i) => follow[i].z - f.z);
      const allHigh = run.flatMap(f => f.high);
      bursts.push({ target, start: first.t, end: last.t, sampled_span: +(last.t - first.t).toFixed(2),
        target_frames: run.length, bot_snapshots: allHigh.length,
        slots: [...new Set(allHigh.map(r => r.slot))].sort((a, b) => a - b).join(';'),
        first_z: first.z, last_z: last.z, next_t: adjacentNext?.t ?? null, next_z: adjacentNext?.z ?? null,
        observed_drop_ge500: steps.some(drop => drop >= 500),
        has_adjacent_target_pair: steps.length > 0,
        largest_adjacent_z_drop: steps.length ? Math.max(...steps) : null,
        max_same_frame_z_spread: Math.max(...follow.map(f => f.spread)),
        player_entity_seen: follow.some(f => f.actor !== 'not_in_player_frame'),
        player_titan_seen: follow.some(f => f.actor === 'player_titan') });
      run = [];
    }
    for (const f of frames) {
      if (run.length && f.t - run.at(-1).t > GAP) finish(null);
      if (f.high.length) run.push(f);
      else finish(f);
    }
    finish(null);
  }
  return bursts.sort((a, b) => a.start - b.start || a.target - b.target);
}

function recoveryContext(rows, events) {
  const bySlot = groups(rows.filter(r => r.bot === 1), r => r.slot);
  for (const a of bySlot.values()) a.sort((a, b) => a.t - b.t);
  const recovery = events.filter(e => e.kind === 'recovery').map(e => ({ ...e,
    t: Number(e.t), slot: Number(e.slot), x: Number(e.x), y: Number(e.y), z: Number(e.z) })).sort((a, b) => a.t - b.t || a.slot - b.slot);
  const lastRecovery = new Map();
  return recovery.map(e => {
    // Strictly preceding frames only: same-time BOT_TRACE may follow this event.
    const preceding = (bySlot.get(e.slot) ?? []).filter(r => r.t < e.t - EPS);
    const recent = preceding.slice(-3), last = recent.at(-1);
    const lastGap = last ? +(e.t - last.t).toFixed(2) : null;
    const sameLivePilot = recent.length === 3 && last.t - recent[0].t >= 3.9
      && recent.every(r => livePilot(r) && r.id === last.id)
      && recent.slice(1).every((r, i) => r.t - recent[i].t <= GAP);
    const engageContext = sameLivePilot && recent.every(r => r.state === 'engage' && r.visible === 1);
    const maxDisplacement = recent.length === 3 ? Math.max(...recent.flatMap(a => recent.map(b => xy(a, b)))) : null;
    const stationary = maxDisplacement !== null && maxDisplacement < 50;
    const pathCounterConstant = recent.length === 3 && recent.every(r => r.path_requests === last.path_requests);
    const recoveryCounterConstant = recent.length === 3 && recent.every(r => r.recoveries === last.recoveries);
    const priorRecovery = lastRecovery.get(e.slot);
    const sinceRecovery = priorRecovery === undefined ? null : +(e.t - priorRecovery).toFixed(2);
    const eventDistance = last ? xy(last, e) : null;
    const candidate = e.reason === 'no_progress' && engageContext && stationary
      && pathCounterConstant && recoveryCounterConstant && eventDistance < 80
      && (sinceRecovery === null || sinceRecovery > 4);
    lastRecovery.set(e.slot, e.t);
    return { t: e.t, slot: e.slot, reason: e.reason, x: e.x, y: e.y, z: e.z,
      preceding_frame_gap: lastGap, preceding_states: recent.map(r => r.state).join(';'),
      same_live_pilot: sameLivePilot, three_visible_engage_frames: engageContext,
      sampled_span: recent.length === 3 ? +(last.t - recent[0].t).toFixed(2) : null,
      max_sampled_xy_displacement: maxDisplacement, event_xy_from_last_frame: eventDistance,
      path_counter_constant: pathCounterConstant, recovery_counter_constant: recoveryCounterConstant,
      seconds_since_previous_recovery: sinceRecovery,
      possible_stale_context_025: !!(candidate && lastGap <= 0.25),
      possible_stale_context_050: !!(candidate && lastGap <= 0.50),
      possible_stale_context_210: !!(candidate && lastGap <= GAP) };
  });
}

function selfTest() {
  assert.equal(hashText('a\r\nb\r\n'), hashText('a\nb\n'), 'Provenance survives repository line-ending normalization');
  assert.deepEqual(csv('\uFEFF"state","t"\r\n"a,""b""\nc","2"\r\n'), [{ state: 'a,"b"\nc', t: 2 }]);
  assert.throws(() => csv('"state","t"\n"broken,2'));
  const sample = (t, overrides = {}) => ({ t, slot: 1, id: 10, bot: 1, alive: 1, titan: 0,
    state: 'engage', visible: 1, x: 0, y: 0, z: 0, target: 99, tx: 0, ty: 0,
    tz: 10000 - t * 1000, path_requests: 5, recoveries: 0, ...overrides });
  const rows = [sample(0), sample(0, { slot: 2, id: 11 }), sample(2), sample(4, { tz: 2000 }), sample(8, { tz: 8000 })];
  const bursts = overheadBursts(rows);
  assert.equal(bursts.length, 2, 'Gap splits target bursts');
  assert.equal(bursts[0].bot_snapshots, 3);
  assert.equal(bursts[0].target_frames, 2, 'Bots at the same time are deduplicated');
  assert.equal(bursts[0].observed_drop_ge500, true);
  assert.equal(bursts[1].observed_drop_ge500, false, 'No interpolated drop across a gap');
  assert.equal(overheadBursts([...rows, sample(0, { slot: 3, id: 99, bot: 0, titan: 1 })])[0].player_titan_seen, true);
  const event = { kind: 'recovery', reason: 'no_progress', t: 4.1, slot: 1, x: 0, y: 0, z: 0 };
  const context = [sample(0), sample(2), sample(4), sample(4.1, { state: 'recover' })];
  assert.equal(recoveryContext(context, [event])[0].possible_stale_context_025, true, 'Same-time trace excluded');
  assert.equal(recoveryContext(context.map(r => r.t === 2 ? { ...r, state: 'pursue' } : r), [event])[0].possible_stale_context_210, false);
  assert.equal(recoveryContext(context.map(r => r.t === 2 ? { ...r, id: 20 } : r), [event])[0].possible_stale_context_210, false);
  assert.equal(recoveryContext(context, [{ ...event, t: 6.3 }])[0].possible_stale_context_210, false, 'Old frame excluded');
  assert.equal(recoveryContext(context, [{ ...event, t: 3.9 }, event])[1].possible_stale_context_210, false, 'Recent recovery excluded');
  assert.equal(recoveryContext([sample(3.8), sample(3.9), sample(4)], [event])[0].possible_stale_context_210, false, 'Need four seconds of sampled context');
  assert.equal(recoveryContext(context.map(r => r.t === 2 ? { ...r, alive: 0 } : r), [event])[0].possible_stale_context_210, false, 'Dead sample excluded');
  assert.equal(recoveryContext(context.map(r => r.t === 2 ? { ...r, titan: 1 } : r), [event])[0].possible_stale_context_210, false, 'Titan transition excluded');
  assert.equal(recoveryContext(context.map(r => r.t === 2 ? { ...r, path_requests: 4 } : r), [event])[0].possible_stale_context_210, false, 'New path request excludes conservative context');
  console.log('PASS: CSV, target deduplication/gaps/entity matching, recovery timing/state/life boundaries.');
}

if (process.argv.includes('--self-test')) {
  selfTest();
} else {
  const rootArg = process.argv.indexOf('--repo');
  const repo = rootArg < 0 ? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..') : path.resolve(process.argv[rootArg + 1]);
  const indexPath = 'research/trends-20261025/rounds.json';
  const indexText = fs.readFileSync(path.join(repo, indexPath), 'utf8');
  const specs = JSON.parse(indexText.replace(/^\uFEFF/, ''));
  const results = [], allBursts = [], allRecoveries = [], inputs = new Map();
  for (const s of specs) {
    const load = filename => {
      const relative = `${s.source}/${filename}`;
      const text = fs.readFileSync(path.join(repo, relative), 'utf8');
      inputs.set(relative, hashText(text));
      return text.replace(/^\uFEFF/, '');
    };
    const metadata = JSON.parse(load('metadata.json'));
    assert.match(metadata.build_line, /combat-decisions-v16/, 'Source build must be v16');
    const inWindow = r => Number(r.epoch) === s.epoch && Number(r.t) >= s.window_start - EPS && Number(r.t) <= s.window_end + EPS;
    const rows = csv(load('observations.csv')).filter(r => inWindow(r) && r.map === s.map);
    const events = JSON.parse(load('events.json')).filter(inWindow);
    const high = rows.filter(highEngage);
    assert.equal(high.length, s.overhead_engage_samples, 'Round trim/overhead detector agrees with trend builder');
    const bursts = overheadBursts(rows), recoveries = recoveryContext(rows, events);
    const identity = { source: s.source, map: s.map, epoch: s.epoch, cohort: s.cohort };
    allBursts.push(...bursts.map(r => ({ ...identity, ...r })));
    allRecoveries.push(...recoveries.map(r => ({ ...identity, ...r })));
    const noProgress = recoveries.filter(r => r.reason === 'no_progress');
    results.push({ ...identity, phase: s.phase, window_start: s.window_start, window_end: s.window_end,
      visible_engage_snapshots: s.visible_engage_samples, high_bot_snapshots: high.length,
      high_target_frames: bursts.reduce((n, r) => n + r.target_frames, 0), high_target_bursts: bursts.length,
      bursts_with_observed_drop_ge500: bursts.filter(r => r.observed_drop_ge500).length,
      bursts_with_adjacent_target_pair: bursts.filter(r => r.has_adjacent_target_pair).length,
      bursts_player_entity_seen: bursts.filter(r => r.player_entity_seen).length,
      bursts_player_titan_seen: bursts.filter(r => r.player_titan_seen).length,
      max_high_sampled_span: Math.max(0, ...bursts.map(r => r.sampled_span)),
      median_high_sampled_span: median(bursts.map(r => r.sampled_span)),
      recovery_events: recoveries.length, recovery_reasons: Object.fromEntries([...groups(recoveries, r => r.reason)].map(([k, a]) => [k, a.length])),
      no_progress_events: noProgress.length,
      no_progress_with_three_recent_live_pilot_frames: noProgress.filter(r => r.same_live_pilot && r.preceding_frame_gap <= GAP).length,
      possible_stale_context_025: noProgress.filter(r => r.possible_stale_context_025).length,
      possible_stale_context_050: noProgress.filter(r => r.possible_stale_context_050).length,
      possible_stale_context_210: noProgress.filter(r => r.possible_stale_context_210).length });
  }
  const out = path.join(repo, 'research/decision-context-20261025');
  fs.mkdirSync(out, { recursive: true });
  const writeJSON = (name, value) => fs.writeFileSync(path.join(out, name), JSON.stringify(value, null, 2) + '\n');
  writeJSON('rounds.json', results);
  const examples = allRecoveries.filter(r => r.possible_stale_context_025).map(r => ({
    source: r.source, map: r.map, epoch: r.epoch, slot: r.slot, event_t: r.t, lines: [] }));
  for (const [source, cases] of groups(examples, r => r.source)) {
    const relative = `${source}/archived.log.gz`;
    const bytes = fs.readFileSync(path.join(repo, relative));
    inputs.set(relative, hash(bytes));
    for (const line of zlib.gunzipSync(bytes).toString('utf8').split(/\r?\n/)) {
      const m = line.match(/BOT_(?:PLAYER|TRACE|DECISION|RECOVERY) epoch=(\d+).*?\bt=([\d.]+) slot=(\d+)/);
      if (!m) continue;
      for (const c of cases) if (+m[1] === c.epoch && +m[3] === c.slot && +m[2] >= c.event_t - 4.25 && +m[2] <= c.event_t + 0.15) {
        c.lines.push(line.slice(m.index));
      }
    }
    for (const c of cases) assert.ok(c.lines.some(line => line.startsWith('BOT_RECOVERY')), 'Example recovery exists in original log');
  }
  writeJSON('strict-recovery-examples.json', examples);
  for (const relative of ['bp_ort/src/bots/progress_watchdog.rs', 'bp_ort/src/bots/cmds_utils.rs',
    'bp_ort/src/bots/cmds/basic_combat.rs', 'research/decision-context-20261025/watchdog-repro.rs']) {
    inputs.set(relative, hashText(fs.readFileSync(path.join(repo, relative), 'utf8')));
  }
  writeJSON('provenance.json', { tool: 'tools/Analyze-DecisionContext.mjs', tool_sha256: hashText(fs.readFileSync(fileURLToPath(import.meta.url), 'utf8')),
    index: indexPath, index_sha256: hashText(indexText), inputs: [...inputs].map(([file, sha256]) => ({ file, sha256,
      hash_mode: file.endsWith('.gz') ? 'binary' : 'UTF-8 text, CRLF normalized to LF' })),
    limits: 'Text hashes normalize CRLF to LF to match repository text policy; compressed-log hashes use exact bytes. Read METHODS.md before interpreting counts. No game or gameplay changes.' });
  for (const [name, a] of [['overhead-target-bursts.csv', allBursts], ['recovery-context.csv', allRecoveries]]) {
    assert.ok(a.length, `Expected records for ${name}`);
    fs.writeFileSync(path.join(out, name), csvText(a, Object.keys(a[0])));
  }
  const lines = ['# Offline decision-context summary', '',
    'Stable v16 only; same phase windows as the trend review. Target bursts are deduplicated selection observations, not unique Titan drops. Recovery contexts are hypotheses, not confirmed false alarms. See [methods](METHODS.md).', '',
    '| Map | Cohort | Overhead bot snapshots | Target frames | Target bursts | Bursts with observed descent | no_progress events | Possible stale context, <=0.25s / <=0.5s / <=2.1s |',
    '|---|---|---:|---:|---:|---:|---:|---:|'];
  for (const r of results) lines.push(`| ${r.map} | ${r.cohort} (${r.phase}) | ${r.high_bot_snapshots} | ${r.high_target_frames} | ${r.high_target_bursts} | ${r.bursts_with_observed_drop_ge500} | ${r.no_progress_events} | ${r.possible_stale_context_025} / ${r.possible_stale_context_050} / ${r.possible_stale_context_210} |`);
  lines.push('', '## Cohort totals', '');
  for (const [cohort, a] of groups(results, r => r.cohort)) {
    const sum = key => a.reduce((n, r) => n + r[key], 0);
    lines.push(`- ${cohort}: ${a.length} recordings; ${sum('high_bot_snapshots')} overhead bot snapshots, ${sum('high_target_frames')} target frames, ${sum('high_target_bursts')} target bursts; ${sum('bursts_with_observed_drop_ge500')} bursts (${pct(sum('bursts_with_observed_drop_ge500'), sum('high_target_bursts'))}%) show an adjacent >=500-unit Z drop. ${sum('bursts_with_adjacent_target_pair')} bursts have an adjacent target-coordinate pair; the rest lack follow-up. ${sum('no_progress_events')} no_progress events; ${sum('possible_stale_context_025')} / ${sum('possible_stale_context_050')} / ${sum('possible_stale_context_210')} possible stale contexts at the three frame-age thresholds.`);
  }
  fs.writeFileSync(path.join(out, 'SUMMARY.md'), lines.join('\n') + '\n');
  console.log(JSON.stringify({ recordings: results.length, overhead_target_bursts: allBursts.length, recovery_events: allRecoveries.length, output: path.relative(repo, out) }));
}
