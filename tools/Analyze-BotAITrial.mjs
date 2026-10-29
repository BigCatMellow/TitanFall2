// Read-only trial analyzer for native bot decisions and frag input diagnostics.
// Command edges are NOT projectile release, casts, hit rates or kill attribution.
// Usage: node tools/Analyze-BotAITrial.mjs --log nslog.txt [--out report.json]
//        node tools/Analyze-BotAITrial.mjs --baseline old.log --trial new.log [--out report.json]
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const EVENT = /(?:^|[\s\]])(BOT_(?:FRAME|FRAG_INPUT|CLEARANCE|ROUTE_COOLDOWN|DECISION|SKILL|PATH|CORNER|STALL|STUCK))\s/;
const finite = value => Number.isFinite(Number(value)) && value !== undefined && value !== '';
// Raw Titanfall corner jump codes are not automatically JumpTypes enum values.
// Standard Detour 0x04 is an off-mesh flag; all other inferences are provisional.
export function cornerClass(flags, jump) {
  if (!Number.isInteger(flags) || !Number.isInteger(jump) || flags < 0 || flags > 255 || jump < 0 || jump > 255) return 'missing';
  if ((flags & ~7) !== 0) return 'unknown_flags';
  if ((flags & 4) !== 0) return 'offmesh_flag';
  if (jump === 255) return 'unknown_jump';
  if (jump !== 0) return 'coded_jump';
  return 'ordinary_candidate';
}
const classCounter = () => ({ordinary_candidate: 0, offmesh_flag: 0,
  coded_jump: 0, unknown_jump: 0, unknown_flags: 0, missing: 0});
const counter = () => ({
  path_requests_logged: 0, partial_paths_logged: 0, stall_samples_logged: 0,
  stuck_episodes_logged: 0, route_cooldown_events: 0,
  corners_by_class: classCounter(), stall_samples_by_corner_class: classCounter(),
  clearance_duck_starts_logged: 0, clearance_releases_logged: 0,
  clearance_failed_attempts_logged: 0,
  cooldowns_followed_by_switch_within_8s: 0, decision_switches_logged: 0,
  skill_ordnance_requests_logged: 0,
  frag_input_presses: 0, frag_input_releases: 0, frag_orphan_releases: 0,
  frag_unfinished_presses: 0, frag_short_pulses: 0, frag_long_pulses: 0,
  frag_ready_positive_presses: 0, frag_ready_unknown_presses: 0,
});

export function parseBotTrialLine(line) {
  const m = line.match(EVENT);
  if (!m) return null;
  const fields = {};
  for (const part of line.slice(m.index + m[0].length).matchAll(/(?:^|\s)([a-z][a-z_0-9]*)=([^\s]+)/g)) {
    fields[part[1]] = part[2];
  }
  return {type: m[1], ...fields};
}

// Groups by engine epoch rather than bot slot: slots are recycled between lives/maps.
// Does not serialize any raw actor identifiers, target IDs, positions or log lines.
export function summarizeBotTrial(events) {
  const groups = new Map();
  const get = event => {
    const epoch = event.epoch ?? 'missing';
    if (!groups.has(epoch)) groups.set(epoch, {
      map: null, counts: counter(), presses: new Map(), pending: new Map(),
      held: [], invalid_time_events: 0,
      corner_codes: new Map(), stall_codes: new Map(),
      corner_code_overflow: 0, stall_code_overflow: 0,
      frame_samples: 0, invalid_frame_samples: 0,
      first_frame_at: null, last_frame_at: null, frame_maps: new Set(),
    });
    return groups.get(epoch);
  };
  for (const e of events) {
    if (!e) continue;
    const g = get(e), c = g.counts;
    if (e.type === 'BOT_FRAME') {
      if (typeof e.map === 'string' && /^mp_[a-z0-9_]+$/.test(e.map)) {
        g.map = e.map;
        g.frame_maps.add(e.map);
      }
      if (finite(e.t) && Number(e.t) >= 0) {
        const t = Number(e.t);
        g.frame_samples++;
        g.first_frame_at = Math.min(g.first_frame_at ?? t, t);
        g.last_frame_at = Math.max(g.last_frame_at ?? t, t);
      } else g.invalid_frame_samples++;
      continue;
    }
    if (e.type === 'BOT_PATH') { c.path_requests_logged++; if (e.partial === '1') c.partial_paths_logged++; }
    else if (e.type === 'BOT_STALL') c.stall_samples_logged++;
    // Count raw code pairs, never actors, positions, target handles or log lines.
    if (e.type === 'BOT_CORNER' || e.type === 'BOT_STALL') {
      const f = Number(e.type === 'BOT_CORNER' ? e.flags : e.corner_flags);
      const j = Number(e.type === 'BOT_CORNER' ? e.jump : e.corner_jump);
      const flags = Number.isInteger(f) && e[e.type === 'BOT_CORNER' ? 'flags' : 'corner_flags'] !== undefined ? f : NaN;
      const jump = Number.isInteger(j) && e[e.type === 'BOT_CORNER' ? 'jump' : 'corner_jump'] !== undefined ? j : NaN;
      const kind = cornerClass(flags, jump);
      (e.type === 'BOT_CORNER' ? c.corners_by_class : c.stall_samples_by_corner_class)[kind]++;
      const map = e.type === 'BOT_CORNER' ? g.corner_codes : g.stall_codes;
      if (kind !== 'missing') {
        const key = `${flags}:${jump}`;
        if (map.has(key)) map.set(key, map.get(key) + 1);
        else if (map.size < 64) map.set(key, 1);
        else if (e.type === 'BOT_CORNER') g.corner_code_overflow++;
        else g.stall_code_overflow++;
      }
    }
    else if (e.type === 'BOT_STUCK') c.stuck_episodes_logged++;
    else if (e.type === 'BOT_SKILL' && e.ordnance && e.ordnance !== '-') c.skill_ordnance_requests_logged++;

    const needsTime = ['BOT_ROUTE_COOLDOWN', 'BOT_DECISION', 'BOT_FRAG_INPUT', 'BOT_CLEARANCE'].includes(e.type);
    if (!needsTime) continue;
    if (!finite(e.t) || !e.slot || !/^\d+$/.test(e.slot)) { g.invalid_time_events++; continue; }
    const at = Number(e.t), slot = e.slot;
    if (e.type === 'BOT_CLEARANCE') {
      // Transition logs, never proof that an obstacle was traversed.
      if (e.intent === 'Duck') c.clearance_duck_starts_logged++;
      else if (e.intent === 'Normal') c.clearance_releases_logged++;
      else if (e.intent === 'Failed') c.clearance_failed_attempts_logged++;
    } else if (e.type === 'BOT_ROUTE_COOLDOWN') {
      c.route_cooldown_events++;
      g.pending.set(slot, {at, matched: false});
    } else if (e.type === 'BOT_DECISION') {
      c.decision_switches_logged++;
      const p = g.pending.get(slot);
      if (p && !p.matched && at >= p.at && at - p.at <= 8) {
        c.cooldowns_followed_by_switch_within_8s++; p.matched = true;
      }
    } else if (e.type === 'BOT_FRAG_INPUT') {
      if (e.edge === 'press') {
        c.frag_input_presses++;
        if (e.ready === '1') c.frag_ready_positive_presses++;
        if (e.ready === '-1' || e.ready === undefined) c.frag_ready_unknown_presses++;
        // Losing a previous release is recorded rather than silently paired.
        if (g.presses.has(slot)) c.frag_unfinished_presses++;
        g.presses.set(slot, at);
      } else if (e.edge === 'release') {
        c.frag_input_releases++;
        const since = g.presses.get(slot);
        if (since === undefined || at < since) { c.frag_orphan_releases++; continue; }
        g.presses.delete(slot);
        const duration = at - since;
        g.held.push(duration);
        if (duration <= 0.20) c.frag_short_pulses++;
        else c.frag_long_pulses++;
      }
    }
  }
  const cohorts = [...groups.values()].map((g, i) => {
    const c = g.counts;
    c.frag_unfinished_presses += g.presses.size;
    const n = g.held.length;
    const sorted = [...g.held].sort((a, b) => a - b);
    const sortedCodes = map => [...map].map(([key, count]) => {
      const [flags, jump] = key.split(':').map(Number);
      return {flags, jump, count};
    }).sort((a, b) => b.count - a.count || a.flags - b.flags || a.jump - b.jump);
    return {
      cohort: i + 1, map: g.map, ...c,
      input_hold_seconds: {matched_edges: n,
        median: n ? sorted[Math.floor((n - 1) / 2)] : null,
        maximum: n ? sorted[n - 1] : null},
      raw_corner_codes: sortedCodes(g.corner_codes),
      raw_stalled_corner_codes: sortedCodes(g.stall_codes),
      corner_code_overflow: g.corner_code_overflow,
      stall_code_overflow: g.stall_code_overflow,
      telemetry_window: {
        frame_samples: g.frame_samples,
        observed_span_s: g.frame_samples >= 2 ? g.last_frame_at - g.first_frame_at : null,
        map_conflict: g.frame_maps.size > 1,
        invalid_frame_samples: g.invalid_frame_samples,
      },
      ignored_events_without_valid_slot_time: g.invalid_time_events,
    };
  });
  return {
    schema_version: 1, cohorts,
    limits: [
      'BOT_FRAG_INPUT measures final native offhand command edges, not a confirmed engine throw, projectile, fuse, collision, self-damage or enemy hit.',
      'BOT_SKILL counts successful input starts as reported by the bot policy, not casts. BOT_ROUTE_COOLDOWN counts per-bot decisions, not successful navigation.',
      'BOT_CLEARANCE counts observed native crouch-intent transitions, not player animation, successful passage, slide or wall-run. Counter snapshots in logs are not summed.',
      'BOT_CORNER classes are raw candidate labels, not validated Titanfall traversal actions. A 0x04 off-mesh flag follows standard Detour; the 8-bit jump code is not assumed to equal the JumpTypes bitmask enum.',
      'BOT_STALL records the current last-known corner metadata, which may be stale or absent. Its class distribution is descriptive, not a per-link failure rate; logged corner visits do not prove completed traversal.',
      'BOT_DECISION logs target changes only when telemetry is enabled. A switch after a cooldown is temporal proximity, not a causal proof of recovery.',
      'Unfinished input pulses include log truncation, inventory changes, respawns and missing events; no such case alone establishes a stuck button.',
      'Counts are whole-epoch diagnostic events, not played-only windows or rates. Compare matched map/cohort exposure and independently validated damage/death results.',
      'BOT_FRAME span is the difference between earliest and latest *sampled* engine times, not active bot-seconds, matched playtime, or validated exposure; sparse/truncated logs can mislead.',
    ],
  };
}

export function parseBotTrialLog(text) {
  return summarizeBotTrial(text.split(/\r?\n/).map(parseBotTrialLine).filter(Boolean));
}


 // Conservative comparison gate. It never labels a behavioral improvement or
 // converts whole-epoch event counts to rates without validated bot exposure.
export function assessTrialCoverage(baseline, trial) {
  const warnings = [];
  const maps = result => new Map(result.cohorts.filter(c => c.map && !c.telemetry_window?.map_conflict)
    .map(c => [c.map, result.cohorts.filter(other => other.map === c.map && !other.telemetry_window?.map_conflict)]));
  const bMaps = maps(baseline), tMaps = maps(trial);
  const unknown = result => result.cohorts.filter(c => !c.map || c.telemetry_window?.map_conflict).length;
  if (unknown(baseline) || unknown(trial))
    warnings.push('One or more epochs lack a trustworthy BOT_FRAME map label; enable native telemetry for both runs.');
  const baselineOnly = [...bMaps.keys()].filter(map => !tMaps.has(map)).sort();
  const trialOnly = [...tMaps.keys()].filter(map => !bMaps.has(map)).sort();
  if (baselineOnly.length || trialOnly.length)
    warnings.push('Baseline and trial include different maps; do not compare their pooled event totals.');
  const shared = [...bMaps.keys()].filter(map => tMaps.has(map)).sort();
  if (!shared.length) warnings.push('No common map has identifiable epochs in both logs.');
  const byMap = shared.map(map => {
    const bs = bMaps.get(map), ts = tMaps.get(map);
    const bSpans = bs.map(c => c.telemetry_window?.observed_span_s);
    const tSpans = ts.map(c => c.telemetry_window?.observed_span_s);
    const valid = spans => spans.every(v => Number.isFinite(v) && v > 0);
    if (bs.length !== ts.length)
      warnings.push(`Map ${map} has unequal baseline/trial epoch counts; manually match rounds.`);
    if (!valid(bSpans) || !valid(tSpans))
      warnings.push(`Map ${map} lacks at least two valid BOT_FRAME samples in an epoch.`);
    // Only compare the sampled spans automatically when one epoch per map.
    if (bs.length === 1 && ts.length === 1 && valid(bSpans) && valid(tSpans)
      && Math.abs(bSpans[0] - tSpans[0]) / Math.max(bSpans[0], tSpans[0]) > 0.10)
      warnings.push(`Map ${map} has more than 10% difference in observed telemetry span; verify equivalent exposure.`);
    return {map, baseline_epochs: bs.length, trial_epochs: ts.length,
      baseline_observed_spans_s: bSpans, trial_observed_spans_s: tSpans};
  });
  return {
    status: warnings.length ? 'coverage_warnings' : 'metadata_present_manual_review_required',
    shared_maps: shared, baseline_only_maps: baselineOnly, trial_only_maps: trialOnly,
    unknown_or_conflicted_baseline_epochs: unknown(baseline),
    unknown_or_conflicted_trial_epochs: unknown(trial),
    by_map: byMap, warnings,
    interpretation: 'Matching map names and sampled frame spans do NOT establish matching active pilot exposure, configuration, causality, frag deaths, or navigation success. Verify trials with the independent played-window and weapon-notebook evidence.',
  };
}

function main() {
  const args = process.argv.slice(2);
  const option = name => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const log = option('--log'), baseline = option('--baseline'), trial = option('--trial');
  if (!(log && !baseline && !trial) && !(!log && baseline && trial))
    throw new Error('Supply --log PATH or both --baseline PATH and --trial PATH');
  const read = file => parseBotTrialLog(fs.readFileSync(file, 'utf8'));
  const report = log ? read(log) : (() => {
    const b = read(baseline), t = read(trial);
    return {schema_version: 1, baseline: b, trial: t,
      coverage_review: assessTrialCoverage(b, t),
      comparison_note: 'Side-by-side raw diagnostic counts only; coverage checks are not a claim of matched active exposure or gameplay improvement.'};
  })();
  const out = option('--out');
  if (out) {
    fs.mkdirSync(path.dirname(out), {recursive: true});
    fs.writeFileSync(out, JSON.stringify(report, null, 2) + '\n');
  }
  console.log(JSON.stringify(report, null, 2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
