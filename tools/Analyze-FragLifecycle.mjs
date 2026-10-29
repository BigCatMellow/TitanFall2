// Read-only analyzer for the optional, locally patched Northstar frag probe.
// A returned grenade entity is NOT evidence of detonation, collision or damage.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const KNOWN = new Set(['prep', 'spawn', 'spawn_null', 'release_callback',
  'cancel_drop_callback', 'forced_release_request', 'death_drop']);
const num = value => typeof value === 'string' && value.length > 0 && Number.isFinite(Number(value))
  ? Number(value) : null;
export function parseFragStage(line) {
  const index = line.indexOf('BT_FRAG_STAGE ');
  if (index < 0) return null;
  const fields = {};
  for (const match of line.slice(index + 'BT_FRAG_STAGE '.length)
    .matchAll(/(?:^|\s)([a-z_0-9]+)=([^\s]+)/g))
    fields[match[1]] = match[2];
  if (fields.schema !== '1' || !KNOWN.has(fields.stage)) return null;
  const time = num(fields.t), owner = num(fields.owner),
    weapon = num(fields.weapon), projectile = num(fields.projectile);
  if (time === null || time < 0 || owner === null || owner < 0
    || weapon === null || weapon < 0 || projectile === null
    || !Number.isInteger(owner) || !Number.isInteger(weapon)
    || !Number.isInteger(projectile)) return null;
  const map = /^mp_[a-z0-9_]+$/.test(fields.map || '') ? fields.map : 'unknown';
  return {map, t: time, stage: fields.stage, owner, weapon, projectile,
    fuse: num(fields.fuse_s), gap: num(fields.owner_gap),
    cook: num(fields.cook_s)};
}
const fresh = () => ({
  events_logged: 0, prep_events: 0, spawned_entities: 0, spawn_null_events: 0,
  release_callbacks: 0, cancel_drop_callbacks: 0, forced_release_requests: 0,
  death_drop_callbacks: 0, death_drops_with_logged_spawn: 0,
  duplicate_projectile_spawn_events: 0, spawn_with_fuse_under_0_25s: 0,
  spawn_with_owner_gap_under_120: 0, invalid_spawn_handles: 0,
  tracked_projectiles_overflow: 0,
});
export function summarizeFragStages(events) {
  // Entity handles may be recycled when a map restarts. Never deduplicate
  // projectiles across separate observed map/time segments. All records are
  // diagnostic log slices, NOT proven full match sessions.
  const segments = [], nextOrdinal = new Map();
  let active = null;
  for (const e of events) {
    if (!e) continue;
    if (!active || active.map !== e.map || e.t + 0.5 < active.lastTime) {
      const ordinal = (nextOrdinal.get(e.map) || 0) + 1;
      nextOrdinal.set(e.map, ordinal);
      active = {map: e.map, segment: ordinal, firstTime: e.t, lastTime: e.t,
        counts: fresh(), projectiles: new Set()};
      segments.push(active);
    } else active.lastTime = Math.max(active.lastTime, e.t);
    const g = active, c = g.counts;
    c.events_logged++;
    if (e.stage === 'prep') c.prep_events++;
    if (e.stage === 'release_callback') c.release_callbacks++;
    if (e.stage === 'cancel_drop_callback') c.cancel_drop_callbacks++;
    if (e.stage === 'forced_release_request') c.forced_release_requests++;
    if (e.stage === 'spawn_null') c.spawn_null_events++;
    if (e.stage === 'spawn') {
      if (e.projectile < 0) { c.invalid_spawn_handles++; continue; }
      const key = e.projectile;
      if (g.projectiles.has(key)) { c.duplicate_projectile_spawn_events++; continue; }
      if (g.projectiles.size >= 2048) { c.tracked_projectiles_overflow++; continue; }
      g.projectiles.add(key);
      c.spawned_entities++;
      if (e.fuse !== null && e.fuse >= 0 && e.fuse < 0.25)
        c.spawn_with_fuse_under_0_25s++;
      if (e.gap !== null && e.gap >= 0 && e.gap < 120)
        c.spawn_with_owner_gap_under_120++;
    }
    if (e.stage === 'death_drop') {
      c.death_drop_callbacks++;
      if (e.projectile >= 0 && g.projectiles.has(e.projectile))
        c.death_drops_with_logged_spawn++;
    }
  }
  return {
    schema_version: 1,
    maps: segments.sort((a, b) => a.map.localeCompare(b.map) || a.segment - b.segment)
      .map(g => ({map: g.map, segment: g.segment, ...g.counts})),
    limits: [
      'spawned_entities counts observed server FireWeaponGrenade return values, not verified detonation, collision, release animation completion, or damage.',
      'prep/release_callback/cancel_drop_callback/forced_release_request are script invocation observations; they may not pair one-to-one with spawned entities.',
      'death_drop_callbacks are a script branch, not proof of explosion or causal self-damage. Short fuse and nearby owner at spawn are inspection candidates, NOT danger thresholds.',
      'Only exact projectile handle equality is used for within-log spawn-to-death-drop association; handles are not emitted. Reused handles and partial logs remain confounders.',
      'No BOT_FRAG_INPUT per-bot slot or WNOTE_HIT attacker is joined to these lifecycle events; the identifier domains and causality have not been validated.',
      'Maps are divided into observed log segments on map change or >0.5s clock rollback. This reduces cross-round handle reuse but does not prove a complete match or globally unique entity identity.',
      'Counts are per-map-segment log totals, not normalized throws, game time, player life, matched A/B, or self-kills. Keep native session logs private.',
    ],
  };
}
export function analyzeFragLog(content) {
  const lines = content.split(/\r?\n/);
  const stages = lines.map(parseFragStage).filter(Boolean);
  const summary = summarizeFragStages(stages);
  // Faults are not gameplay events. Even one exception makes the absence of
  // grenade stages unreliable. Never return an apparently clean zero.
  const faults = lines.filter(line =>
    /(?:^|[\s\]])BT_FRAG_PROBE_ERROR schema=1(?:\s|$)/.test(line)).length;
  const empty = stages.length === 0;
  return {...summary,
    probe_errors_logged: faults,
    probe_status: faults > 0 ? 'probe_error_review_required'
      : empty ? 'no_valid_stage_events_cannot_infer_no_grenades'
        : 'stage_events_present_runtime_validation_required',
    limits: [...summary.limits,
      'A BT_FRAG_PROBE_ERROR invalidates absence-of-events conclusions. No valid stage events may mean the probe was disabled, not installed, lacked hooks, or did not observe a throw.'],
  };
}
function main(args) {
  const option = k => { const i = args.indexOf(k); return i < 0 ? undefined : args[i + 1]; };
  const log = option('--log'), out = option('--out');
  if (!log || args.length !== (out ? 4 : 2)) throw new Error(
    'Usage: node tools/Analyze-FragLifecycle.mjs --log PRIVATE.log [--out PRIVATE.json]');
  const report = analyzeFragLog(fs.readFileSync(log, 'utf8'));
  if (out) {
    if (path.resolve(out) === path.resolve(log))
      throw new Error('Refusing to overwrite the private source log');
    fs.mkdirSync(path.dirname(out), {recursive: true});
    fs.writeFileSync(out, JSON.stringify(report, null, 2) + '\n', {flag: 'wx'});
  }
  console.log(JSON.stringify(report, null, 2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url))
  main(process.argv.slice(2));
