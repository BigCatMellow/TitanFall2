import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
const args = process.argv.slice(2);
const quick = args.includes('--quick');
const weaponIntegration = args.includes('--weapons');
const run = args[args.indexOf('--run') + 1], out = args[args.indexOf('--out') + 1];
if (!args.includes('--run') || !args.includes('--out')) throw new Error('Use --run PRIVATE_RUN --out REPORT_DIRECTORY');
const progress = JSON.parse(fs.readFileSync(path.join(run, 'progress.json'), 'utf8').replace(/^\uFEFF/, ''));
const source = fs.existsSync(path.join(run, 'raw-session.log')) ? path.join(run, 'raw-session.log') : progress.log;
const bytes = fs.readFileSync(source), lines = bytes.toString('utf8').split(/\r?\n/);
const frames = new Map(), traces = [], weapons = [], actions = [], ready = [], targetStates = new Map(), phases = new Map();
const evidence = [], beginnings = [], errors = [];
let context = null, core = null;
function fields(line) { return Object.fromEntries([...line.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m => [m[1], m[2]])); }
const key = r => `${r.epoch}|${(+r.t).toFixed(2)}|${r.slot}`;
for (const line of lines) {
  if (line.includes('NorthstarLauncher version:')) core = line.split('version:')[1].trim();
  if (/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked/.test(line)) errors.push(line.replace(/^.*?\] \[error\] /, ''));
  const match = line.match(/\b(BOT_[A-Z_]+|DECISION_TEST[A-Z_]*|WEAPON_CHECK|WEAPON_VALUE|WEAPON_INTEGRATION)\b/);
  if (!match) continue;
  const kind = match[1], text = line.slice(match.index), f = fields(text);
  // Deliberately publish only authored bot/test diagnostics; no general log,
  // account IDs, personal preset names, auth fields or stack-variable dumps.
  evidence.push(text);
  if (kind === 'BOT_FRAME') context = { epoch: f.epoch, map: f.map };
  if (kind === 'DECISION_TEST_BEGIN') {
    if (!context || context.map !== f.map) throw new Error('Ambiguous phase/epoch association');
    phases.set(context.epoch, +f.phase); beginnings.push({ ...f, epoch: +context.epoch });
  }
  if (kind === 'BOT_PLAYER') frames.set(key(f), f);
  if (kind === 'BOT_WEAPON') weapons.push(f);
  if (kind === 'BOT_ACTION') actions.push(f);
  if (kind === 'BOT_READY' && context && context.map === f.map) ready.push({ ...f, epoch: context.epoch });
  if (kind === 'BOT_TARGET_STATE') targetStates.set(`${f.epoch}|${f.id}`, f);
  if (kind === 'BOT_TRACE') {
    const state = targetStates.get(`${f.epoch}|${f.target}`);
    traces.push({ ...f, target_known_hotdropping: !!(state && state.eligible === '0' && +state.t <= +f.t) });
  }
}
function pilot(r) { const p = frames.get(key(r)); return p?.alive === '1' && p?.bot === '1' && p?.titan === '0'; }
const phaseRows = [];
for (const start of beginnings) {
  const epoch = String(start.epoch);
  const ts = traces.filter(r => r.epoch === epoch && pilot(r));
  const ws = weapons.filter(r => r.epoch === epoch && pilot(r));
  const rs = ready.filter(r => r.epoch === epoch);
  const ac = actions.filter(r => r.epoch === epoch && pilot(r));
  const counts = {};
  for (const w of ws) counts[w.weapon] = (counts[w.weapon] ?? 0) + 1;
  const tactical = {};
  for (const r of rs) {
    tactical[r.tactical] ??= { observations: 0, ready: 0, not_ready: 0, highest_shot_counter: 0, lowest_observed_clip: Infinity };
    const s = tactical[r.tactical]; s.observations++;
    s[r.tactical_ready === 'true' ? 'ready' : 'not_ready']++;
    s.highest_shot_counter = Math.max(s.highest_shot_counter, +r.tactical_shots);
    s.lowest_observed_clip = Math.min(s.lowest_observed_clip, +r.tactical_clip);
  }
  phaseRows.push({ phase: +start.phase, epoch: +epoch, map: start.map, bots_at_begin: +start.bots, imc_bots_at_begin: +start.imc,
    live_pilot_trace_samples: ts.length,
    selected_known_hotdropping_pet_samples: ts.filter(r => r.target_known_hotdropping).length,
    overhead_visible_engage_samples: ts.filter(r => r.state === 'engage' && r.visible === '1' && +r.tz - +frames.get(key(r)).z > 5000).length,
    actual_current_weapon_samples: counts, tactical_observations: tactical,
    largest_tactical_pulse_counter: Math.max(0, ...ac.map(r => +r.tactical_pulses)),
    largest_ordnance_pulse_counter: Math.max(0, ...ac.map(r => +r.ordnance_pulses)),
    largest_blocked_request_counter: Math.max(0, ...ac.map(r => +r.blocked)) });
}
const matrix = phaseRows.find(r => r.phase === 4);
const required = ['mp_weapon_rspn101','mp_weapon_car','mp_weapon_shotgun','mp_weapon_g2','mp_weapon_epg','mp_weapon_lstar'];
const addedProfiles = ['mp_weapon_alternator_smg','mp_weapon_mastiff','mp_weapon_esaw','mp_weapon_wingman','mp_weapon_semipistol'];
const weaponChecks=lines.filter(l=>l.includes('WEAPON_CHECK ')).map(fields);
const weaponValues=lines.filter(l=>l.includes('WEAPON_VALUE ')).map(fields);
const completeWeaponCheck=lines.some(l=>l.includes('WEAPON_INTEGRATION: COMPLETE')&&l.includes('respawn=true')&&l.includes('bots_opt_in=false'));
const expectedWeaponCounts={reload:10,ads:4,balance:8,automatic:7,bot_exclusion_and_strip:3};
const weaponCounts=Object.fromEntries(Object.keys(expectedWeaponCounts).map(k=>[k,weaponChecks.filter(r=>r.kind===k).length]));
const costSamples = ready.filter(r => r.tactical_cost !== undefined && r.ordnance_cost !== undefined);
const readinessCost = {
  samples: costSamples.length,
  unaffordable_tactical_samples: costSamples.filter(r => +r.tactical_clip < +r.tactical_cost).length,
  unaffordable_ordnance_samples: costSamples.filter(r => +r.ordnance_clip < +r.ordnance_cost).length,
  incorrectly_ready_samples: costSamples.filter(r => (r.tactical_ready === 'true' && +r.tactical_clip < +r.tactical_cost)
    || (r.ordnance_ready === 'true' && +r.ordnance_clip < +r.ordnance_cost)).length,
};
const checks = {
  watcher_completed_client_suite: progress.state === 'passed' && !progress.dedicated,
  actual_core_version: core === '1.31.14.0', no_script_or_native_errors: errors.length === 0,
  all_phases_started: (quick ? [4,6] : [0,1,2,3,4,6]).every(p => phaseRows.some(r => r.phase === p)),
  controlled_population_8v8: phaseRows.filter(r => r.phase <= 4).length === (quick ? 1 : 5) && phaseRows.filter(r => r.phase <= 4).every(r => r.bots_at_begin === 16 && r.imc_bots_at_begin === 8),
  human_plus_15_bot_return: phaseRows.some(r => r.phase === 6 && r.bots_at_begin === 15),
  six_weapon_classes_observed: !!matrix && required.every(w => matrix.actual_current_weapon_samples[w] > 0),
  ability_pulses_observed: phaseRows.some(r => r.phase >= 2 && r.largest_tactical_pulse_counter > 0),
  no_sampled_filtered_hotdrop_selection: phaseRows.filter(r => r.phase >= 1).every(r => r.selected_known_hotdropping_pet_samples === 0),
  ...(quick ? { final_cost_observed_and_respected: readinessCost.samples > 0 && readinessCost.incorrectly_ready_samples === 0 } : {}),
  ...(weaponIntegration ? {
    added_weapon_profiles_observed: !!matrix && addedProfiles.every(w=>matrix.actual_current_weapon_samples[w]>0),
    human_weapon_matrix_completed: completeWeaponCheck && Object.entries(expectedWeaponCounts).every(([k,n])=>weaponCounts[k]===n),
  } : {}),
};
const result = { core, run: path.basename(run), state: progress.state,
  source_sha256: crypto.createHash('sha256').update(bytes).digest('hex'), checks, readiness_cost: readinessCost, phases: phaseRows,
  ...(weaponIntegration ? {weapon_check_counts:weaponCounts,weapon_checks:weaponChecks,weapon_values:weaponValues} : {}),
  limits: 'Controlled smoke/integration coverage, not a randomized balance or stability guarantee. Ability shot/resource counters are observations, not cast-success totals. Native pulse counters reset across lives/hulls. Selected hotdrop counts use preceding reported state and two-second snapshots. Mixed loadouts occur only in the test harness. Private raw log and save data are not published.' };
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'runtime-review.json'), JSON.stringify(result, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'bot-test-evidence.log.gz'), zlib.gzipSync(Buffer.from(evidence.join('\n') + '\n')));
const md = ['# Candidate runtime review', '', `Run: ${result.run}; watcher: ${progress.state}; actual core: ${core}.`, '',
  '| Check | Result |','|---|---|', ...Object.entries(checks).map(([k,v]) => `| ${k} | ${v ? 'PASS' : 'NOT SATISFIED'} |`), '',
  '| Phase | Map | Bots | Live pilot trace samples | Known hotdrop selections | Largest tactical pulse counter |',
  '|---|---|---:|---:|---:|---:|', ...phaseRows.map(r => `| ${r.phase} | ${r.map} | ${r.bots_at_begin} | ${r.live_pilot_trace_samples} | ${r.selected_known_hotdropping_pet_samples} | ${r.largest_tactical_pulse_counter} |`), '', result.limits];
fs.writeFileSync(path.join(out, 'RUNTIME.md'), md.join('\n') + '\n');
console.log(JSON.stringify({ state: result.state, checks, phases: phaseRows.length, published_diagnostic_lines: evidence.length }));
if (!args.includes('--allow-running') && Object.values(checks).some(v => !v)) process.exitCode = 1;
