// Summarize bot_nav_diagnostics output from a private Northstar log.
// Read-only: prints/writes derived aggregates; never copies raw log lines.
//
// Usage:
//   node tools/Analyze-NavDiagnostics.mjs --log <nslog.txt> [--out <dir>]
//
// Decision rule from research/bot-capability-20261027/README.md (Experiment 1):
//   link_or_partial_share >= 0.5  -> prioritise link/partial-route handling
//   duck_only_share      >= 0.3  -> crouch recovery is justified for that map
// Stall samples are grouped into incidents (same slot, within 12 s and 192
// units of the previous stall), so overlapping samples are not double counted.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const TYPES = ['BOT_PATH', 'BOT_CORNER', 'BOT_STALL', 'BOT_STUCK', 'BOT_CROUCH', 'BOT_VIEWCHECK'];

export function parseDiag(line) {
  const m = line.match(/(?:^|\s|\])(BOT_(?:PATH|CORNER|STALL|STUCK|CROUCH|VIEWCHECK))\s/);
  if (!m) return null;
  const rest = line.slice(m.index + m[0].length - 1);
  const fields = {};
  // key=value pairs; VIEWCHECK values may contain brackets/spaces inside (...)
  for (const f of rest.matchAll(/(?:^|\s)([a-z_]+)=((?:\([^)]*\))|(?:\[[^\]]*\])|[^\s]+)/g)) fields[f[1]] = f[2];
  return {type: m[1], ...fields};
}

const isLink = (flags, jump) => {
  const f = Number(flags), j = Number(jump);
  return (Number.isFinite(f) && f >= 0 && (f & 0x04) !== 0) || (Number.isFinite(j) && j > 0 && j !== 255);
};

export function analyzeDiag(events) {
  const out = {schema_version: 1, paths: {requests: 0, partial: 0, failures: 0, suppressed: 0, with_links: 0},
    corners: {total: 0, links: 0, by_jump: {}, by_flags: {}},
    stalls: {samples: 0, incidents: 0, link_or_partial: 0, duck_only: 0, blocked: 0, stand_clear: 0, unknown: 0, by_reason: {}, by_state: {}},
    stuck: {episodes: 0, by_state: {}, visible: 0, titan: 0},
    crouch: {tests: 0, by_fit: {}, attempts_max: 0, successes_max: 0, failures_max: 0},
    viewcheck: {samples: 0, plausible: 0, examples: []}};
  let epoch = null;
  const lastStall = new Map();
  const crouchBySlot = new Map();
  for (const e of events) {
    if (e.epoch && e.epoch !== epoch) { epoch = e.epoch; lastStall.clear(); }
    if (e.type === 'BOT_PATH') {
      out.paths.requests++; out.paths.suppressed += Number(e.suppressed) || 0;
      if (e.ok === '0') out.paths.failures++;
      if (e.partial === '1') out.paths.partial++;
      if (Number(e.links) > 0) out.paths.with_links++;
    } else if (e.type === 'BOT_CORNER') {
      out.corners.total++;
      out.corners.by_jump[e.jump] = (out.corners.by_jump[e.jump] || 0) + 1;
      out.corners.by_flags[e.flags] = (out.corners.by_flags[e.flags] || 0) + 1;
      if (isLink(e.flags, e.jump)) out.corners.links++;
    } else if (e.type === 'BOT_STALL') {
      out.stalls.samples++;
      const t = Number(e.t), x = Number(e.x), y = Number(e.y), prev = lastStall.get(e.slot);
      const same = prev && t >= prev.t && t - prev.t < 12 && Math.hypot(x - prev.x, y - prev.y) < 192;
      lastStall.set(e.slot, {t, x, y});
      if (same) continue; // overlapping sample of the same incident
      out.stalls.incidents++;
      out.stalls.by_reason[e.reason] = (out.stalls.by_reason[e.reason] || 0) + 1;
      out.stalls.by_state[e.state] = (out.stalls.by_state[e.state] || 0) + 1;
      if (isLink(e.corner_flags, e.corner_jump) || e.partial === '1') out.stalls.link_or_partial++;
      const fit = {DuckOnly: 'duck_only', Blocked: 'blocked', StandClear: 'stand_clear'}[e.fit] || 'unknown';
      out.stalls[fit]++;
    } else if (e.type === 'BOT_STUCK') {
      out.stuck.episodes++;
      out.stuck.by_state[e.state] = (out.stuck.by_state[e.state] || 0) + 1;
      if (e.visible === '1') out.stuck.visible++;
      if (e.titan === '1') out.stuck.titan++;
    } else if (e.type === 'BOT_CROUCH') {
      const fit = (e.fit || 'None').replace(/^Some\(|\)$/g, '');
      if (fit !== 'None') { out.crouch.tests++; out.crouch.by_fit[fit] = (out.crouch.by_fit[fit] || 0) + 1; }
      crouchBySlot.set(`${epoch}|${e.slot}`, {a: +e.attempts || 0, s: +e.successes || 0, f: +e.failures || 0});
    } else if (e.type === 'BOT_VIEWCHECK') {
      out.viewcheck.samples++;
      if (e.plausible === '1') out.viewcheck.plausible++;
      if (out.viewcheck.examples.length < 3) out.viewcheck.examples.push({eye_angles: e.eye_angles, view_angles_raw: e.view_angles_raw, eye_height: e.eye_height, stand: e.stand, duck: e.duck});
    }
  }
  for (const v of crouchBySlot.values()) { out.crouch.attempts_max += v.a; out.crouch.successes_max += v.s; out.crouch.failures_max += v.f; }
  const n = out.stalls.incidents;
  out.decision = {
    stall_incidents: n,
    link_or_partial_share: n ? out.stalls.link_or_partial / n : null,
    duck_only_share: n ? out.stalls.duck_only / n : null,
    partial_route_share: out.paths.requests ? out.paths.partial / out.paths.requests : null,
    engage_stuck_share: out.stuck.episodes ? (out.stuck.by_state.engage || 0) / out.stuck.episodes : null,
    recommendation: !n ? 'insufficient stall incidents' :
      out.stalls.link_or_partial / n >= 0.5 ? 'prioritise link/partial-route handling' :
      out.stalls.duck_only / n >= 0.3 ? 'crouch recovery justified' : 'neither threshold met; inspect individual incidents',
  };
  out.limits = 'Derived from sampled diagnostic lines. Link classification assumes the off-mesh flag (0x04) or a nonzero jump type other than 255; confirm the encoding from BOT_CORNER distributions first. Hull fits use engine traces, not visual confirmation. Incidents are grouped per slot (12 s, 192 units); they are not proof of a single physical cause.';
  return out;
}

function main() {
  const args = process.argv.slice(2), arg = k => args.includes(k) ? args[args.indexOf(k) + 1] : null;
  const log = arg('--log');
  if (!log) throw new Error('Missing --log');
  const events = fs.readFileSync(log, 'utf8').split(/\r?\n/).map(parseDiag).filter(Boolean);
  const result = analyzeDiag(events);
  const outDir = arg('--out');
  if (outDir) { fs.mkdirSync(outDir, {recursive: true}); fs.writeFileSync(path.join(outDir, 'nav-diagnostics.json'), JSON.stringify(result, null, 2) + '\n'); }
  console.log(JSON.stringify(result.decision, null, 2));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
export {TYPES};
