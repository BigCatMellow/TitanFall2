// Read-only trial analyzer for native bot decisions and frag input diagnostics.
// Command edges are NOT projectile release, casts, hit rates or kill attribution.
// Usage: node tools/Analyze-BotAITrial.mjs --log nslog.txt [--out report.json]
//        node tools/Analyze-BotAITrial.mjs --baseline old.log --trial new.log [--out report.json]
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const EVENT = /(?:^|[\s\]])(BOT_(?:FRAME|FRAG_INPUT|CLEARANCE|ROUTE_COOLDOWN|DECISION|SKILL|PATH|STALL|STUCK))\s/;
const finite = value => Number.isFinite(Number(value)) && value !== undefined && value !== '';
const counter = () => ({
  path_requests_logged: 0, partial_paths_logged: 0, stall_samples_logged: 0,
  stuck_episodes_logged: 0, route_cooldown_events: 0,
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
    });
    return groups.get(epoch);
  };
  for (const e of events) {
    if (!e) continue;
    const g = get(e), c = g.counts;
    if (e.type === 'BOT_FRAME') {
      if (typeof e.map === 'string' && /^mp_[a-z0-9_]+$/.test(e.map)) g.map = e.map;
      continue;
    }
    if (e.type === 'BOT_PATH') { c.path_requests_logged++; if (e.partial === '1') c.partial_paths_logged++; }
    else if (e.type === 'BOT_STALL') c.stall_samples_logged++;
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
    return {
      cohort: i + 1, map: g.map, ...c,
      input_hold_seconds: {matched_edges: n,
        median: n ? sorted[Math.floor((n - 1) / 2)] : null,
        maximum: n ? sorted[n - 1] : null},
      ignored_events_without_valid_slot_time: g.invalid_time_events,
    };
  });
  return {
    schema_version: 1, cohorts,
    limits: [
      'BOT_FRAG_INPUT measures final native offhand command edges, not a confirmed engine throw, projectile, fuse, collision, self-damage or enemy hit.',
      'BOT_SKILL counts successful input starts as reported by the bot policy, not casts. BOT_ROUTE_COOLDOWN counts per-bot decisions, not successful navigation.',
      'BOT_CLEARANCE counts observed native crouch-intent transitions, not player animation, successful passage, slide or wall-run. Counter snapshots in logs are not summed.',
      'BOT_DECISION logs target changes only when telemetry is enabled. A switch after a cooldown is temporal proximity, not a causal proof of recovery.',
      'Unfinished input pulses include log truncation, inventory changes, respawns and missing events; no such case alone establishes a stuck button.',
      'Counts are whole-epoch diagnostic events, not played-only windows or rates. Compare matched map/cohort exposure and independently validated damage/death results.',
    ],
  };
}

export function parseBotTrialLog(text) {
  return summarizeBotTrial(text.split(/\r?\n/).map(parseBotTrialLine).filter(Boolean));
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
  const report = log ? read(log) : {schema_version: 1, baseline: read(baseline), trial: read(trial),
    comparison_note: 'Side-by-side event counts only: rates and improvement require matched exposure and validated gameplay outcomes.'};
  const out = option('--out');
  if (out) {
    fs.mkdirSync(path.dirname(out), {recursive: true});
    fs.writeFileSync(out, JSON.stringify(report, null, 2) + '\n');
  }
  console.log(JSON.stringify(report, null, 2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
