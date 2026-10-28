// Read-only extension of the played-session review: pilot ordnance outcomes,
// readiness observations and per-round navigation. No raw identifiers exported.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parseDiag, analyzeDiag} from './Analyze-NavDiagnostics.mjs';

const ordnance = new Set(['mp_weapon_frag_grenade', 'mp_weapon_grenade_emp',
  'mp_weapon_thermite_grenade', 'mp_weapon_grenade_gravity', 'mp_weapon_grenade_electric_smoke']);
const fields = line => Object.fromEntries([...line.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m => [m[1], m[2]]));
const countBy = (rows, field) => rows.reduce((o, r) => { o[r[field]] = (o[r[field]] || 0) + 1; return o; }, {});

export function summarizeOrdnance(events) {
  const rounds = []; let current;
  for (const e of events) {
    if (e.type === 'WNOTE_CONTEXT') { current = {map: e.map, hits: new Map(), posts: new Map(), deaths: new Map()}; rounds.push(current); }
    if (!current) continue;
    if (e.type === 'WNOTE_HIT') current.hits.set(e.event, e);
    if (e.type === 'WNOTE_POST') current.posts.set(e.event, e);
    if (e.type === 'WNOTE_DEATH') current.deaths.set(e.event, e);
  }
  return rounds.map((r, i) => {
    const sources = new Map();
    for (const [id, h] of r.hits) {
      if (h.akind !== 'bot' || h.atitan !== 'false' || !ordnance.has(h.gun)) continue;
      if (!sources.has(h.gun)) sources.set(h.gun, {weapon: h.gun, damage_callbacks: 0,
        opposing_damage_callbacks: 0, opposing_callbacks_with_observed_health_loss: 0,
        enemy_pilot_deaths_credited: 0, human_pilot_deaths_credited: 0,
        self_damage_callbacks: 0, self_pilot_deaths_credited: 0,
        friendly_damage_callbacks: 0, friendly_pilot_deaths_credited: 0, forced_callbacks: 0});
      const s = sources.get(h.gun); s.damage_callbacks++;
      const p = r.posts.get(id), d = r.deaths.get(id);
      const paired = p && p.victim === h.victim && p.life === h.life && Number.isFinite(+p.hp_after);
      const lethal = paired && p.hp_after === '0' && d?.victim === h.victim && d.life === h.life;
      if (h.force === 'true') s.forced_callbacks++;
      if (h.attacker === h.victim) { s.self_damage_callbacks++; if (lethal) s.self_pilot_deaths_credited++; }
      else if (h.ateam === h.vteam) { s.friendly_damage_callbacks++; if (lethal) s.friendly_pilot_deaths_credited++; }
      else if (h.force !== 'true') {
        s.opposing_damage_callbacks++;
        if (paired && +p.hp_after < +h.hp) s.opposing_callbacks_with_observed_health_loss++;
        if (lethal) { s.enemy_pilot_deaths_credited++; if (h.vkind === 'human') s.human_pilot_deaths_credited++; }
      }
    }
    return {context: i + 1, map: r.map, sources: [...sources.values()]};
  });
}

export function summarizeReadiness(rows) {
  const groups = new Map();
  for (const r of rows) for (const channel of ['tactical', 'ordnance']) {
    const weapon = r[channel]; if (!weapon) continue;
    const key = channel + '|' + weapon;
    if (!groups.has(key)) groups.set(key, {channel, weapon, samples: 0, not_ready_samples: 0,
      below_cost_samples: 0, min_clip: Infinity, max_clip: -Infinity, nonzero_shot_counter_samples: 0});
    const g = groups.get(key); g.samples++;
    if (r[channel + '_ready'] === 'false') g.not_ready_samples++;
    const clip = Number(r[channel + '_clip']), cost = Number(r[channel + '_cost']);
    if (Number.isFinite(clip)) { g.min_clip = Math.min(g.min_clip, clip); g.max_clip = Math.max(g.max_clip, clip); }
    if (Number.isFinite(clip) && Number.isFinite(cost) && clip < cost) g.below_cost_samples++;
    if (+r[channel + '_shots'] > 0) g.nonzero_shot_counter_samples++;
  }
  return [...groups.values()].map(g => ({...g, min_clip: Number.isFinite(g.min_clip) ? g.min_clip : null,
    max_clip: Number.isFinite(g.max_clip) ? g.max_clip : null}));
}

export function analyzeCapabilities(events, log, analysis) {
  const samples = [], diagnostics = []; let frame;
  const errorMarkers = {};
  for (const line of log.split(/\r?\n/)) {
    const error = line.match(/BOT_ROSTER_ERROR|WNOTE_ERROR|WNOTE_FIRE_ERROR|SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked/);
    if (error) errorMarkers[error[0]] = (errorMarkers[error[0]] || 0) + 1;
    const m = line.match(/(?:^|\])(\s*)(BOT_FRAME|BOT_READY|BOT_SKILL|BOT_COVER|BOT_PLAYER)\s/);
    if (m) {
      const f = fields(line), type = m[2];
      if (type === 'BOT_FRAME') frame = f;
      else samples.push({type, ...f, epoch: f.epoch ?? frame?.epoch});
    }
    const d = parseDiag(line); if (d) diagnostics.push(d);
  }
  const outcomes = summarizeOrdnance(events);
  if (outcomes.length !== analysis.rounds.length) throw new Error('Capability context count mismatch');
  return {schema_version: 1, error_markers_whole_log: errorMarkers,
    rounds: analysis.rounds.map((r, i) => {
      if (outcomes[i].map !== r.map) throw new Error('Capability context map mismatch');
      const inside = e => +e.epoch === r.epoch && +e.t >= r.telemetry_window_start && +e.t <= r.telemetry_window_end;
      const rows = samples.filter(inside), skills = rows.filter(e => e.type === 'BOT_SKILL');
      const covers = rows.filter(e => e.type === 'BOT_COVER');
      const human = rows.filter(e => e.type === 'BOT_PLAYER' && e.bot === '0');
      return {context: r.context, map: r.map, epoch: r.epoch,
        human_presence: {alive_pilot_samples: human.filter(e => e.alive === '1' && e.titan === '0').length,
          alive_titan_samples: human.filter(e => e.alive === '1' && e.titan === '1').length,
          dead_samples: human.filter(e => e.alive === '0').length},
        skill_requests: {lines: skills.length,
          tactical_pulses: skills.filter(e => e.tactical && e.tactical !== '-').length,
          ordnance_pulses: skills.filter(e => e.ordnance && e.ordnance !== '-').length,
          tactical_reasons: countBy(skills.filter(e => e.tactical !== '-'), 'tactical'),
          ordnance_reasons: countBy(skills.filter(e => e.ordnance !== '-'), 'ordnance')},
        readiness: summarizeReadiness(rows.filter(e => e.type === 'BOT_READY')),
        cover: {probes: covers.length, selected_destinations: covers.filter(e => e.found === '1').length,
          no_destination: covers.filter(e => e.found === '0').length},
        bot_pilot_ordnance: outcomes[i].sources,
        navigation: analyzeDiag(diagnostics.filter(inside))};
    }), limits: 'Native observations trimmed to each played context epoch/window. Readiness/resource samples and allowed input pulses are not counts of successful casts or unique uses. Ordnance counts are pilot-attacker/pilot-victim callbacks; Titan attackers excluded. Matching end-of-frame health loss can include concurrent damage: no attributed damage sum or throw accuracy is computed. Lethal credit requires matching context/event/victim/life and zero-health post. Self/friendly/forced cases remain separate. Diagnostic incidents and overlapping movement samples are proxies, not visual observation or a causal before/after trial.'};
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), get = k => args[args.indexOf(k) + 1];
  for (const k of ['--session', '--profile', '--out']) if (!args.includes(k)) throw new Error('Missing ' + k);
  const session = get('--session'), out = get('--out');
  const meta = JSON.parse(fs.readFileSync(path.join(session, 'session.json'), 'utf8').replace(/^\uFEFF/, ''));
  const summary = JSON.parse(fs.readFileSync(path.join(session, 'summary.json'), 'utf8'));
  if (meta.mode !== 'normal_play' || summary.state !== 'complete') throw new Error('Use a completed normal-play session');
  const bytes = fs.readFileSync(path.join(session, 'events.jsonl'));
  const raw = fs.readFileSync(path.join(get('--profile'), 'logs', summary.source_log));
  const analysis = JSON.parse(fs.readFileSync(path.join(out, 'analysis.json'), 'utf8'));
  const sha = data => crypto.createHash('sha256').update(data).digest('hex');
  if (analysis.provenance?.event_sha256 !== sha(bytes) || analysis.provenance?.private_log_sha256 !== sha(raw)) throw new Error('Played analysis provenance mismatch');
  const result = analyzeCapabilities(bytes.toString('utf8').trim().split('\n').map(JSON.parse), raw.toString('utf8'), analysis);
  result.provenance = {...analysis.provenance, trial: meta.trial, trial_overrides: meta.trial_overrides};
  fs.writeFileSync(path.join(out, 'capabilities.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result.rounds.map(r => ({map: r.map, human: r.human_presence,
    requests: r.skill_requests, ordnance: r.bot_pilot_ordnance, cover: r.cover, nav: r.navigation.decision})), null, 2));
}
