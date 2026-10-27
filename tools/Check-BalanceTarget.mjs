// Compare played sessions against the agreed solo balance target (human pilot
// K/D about 3:1). Reads analysis.json files produced by
// tools/Analyze-PlayedWeaponSession.mjs; prints derived numbers only.
//
// Usage: node tools/Check-BalanceTarget.mjs --label baseline a/analysis.json [--label trial b/analysis.json ...]
//
// K/D here = credited human pilot kills / recorded human pilot deaths (pilot
// victims only; not a scoreboard). A map needs >=2 deaths before its ratio is
// reported, otherwise one lucky life dominates it.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export const TARGET = {kd: 3, low: 2.5, high: 3.5, minDeaths: 2};

const median = a => { const b = [...a].sort((x, y) => x - y); return b.length ? (b[Math.floor((b.length - 1) / 2)] + b[Math.floor(b.length / 2)]) / 2 : null; };

export function summarize(analyses) {
  const maps = new Map();
  let kills = 0, deaths = 0, minutes = 0;
  const botSurvival = [];
  for (const a of analyses) {
    for (const r of a.rounds || []) {
      const m = maps.get(r.map) || {map: r.map, rounds: 0, kills: 0, deaths: 0, minutes: 0};
      const mins = Math.max(0, (+r.telemetry_window_end - +r.telemetry_window_start) / 60) || 0;
      m.rounds++; m.kills += +r.human_pilot_kills_credited || 0; m.deaths += +r.human_pilot_deaths_recorded || 0; m.minutes += mins;
      maps.set(r.map, m);
      kills += +r.human_pilot_kills_credited || 0; deaths += +r.human_pilot_deaths_recorded || 0; minutes += mins;
      for (const g of r.qualifying_human_damage_groups || []) if (g.victim_kind === 'bot' && Number.isFinite(+g.median_s)) for (let i = 0; i < (+g.n || 1); i++) botSurvival.push(+g.median_s);
    }
  }
  const verdict = (k, d) => d < TARGET.minDeaths ? 'too few deaths to judge' :
    k / d > TARGET.high ? 'bots too easy' : k / d < TARGET.low ? 'bots too hard' : 'on target';
  const perMap = [...maps.values()].map(m => ({...m, minutes: +m.minutes.toFixed(1),
    kd: m.deaths ? +(m.kills / m.deaths).toFixed(2) : null,
    kills_per_10min: m.minutes ? +(m.kills / m.minutes * 10).toFixed(1) : null,
    deaths_per_10min: m.minutes ? +(m.deaths / m.minutes * 10).toFixed(1) : null,
    verdict: verdict(m.kills, m.deaths)}));
  return {target: TARGET, kills, deaths, minutes: +minutes.toFixed(1),
    kd: deaths ? +(kills / deaths).toFixed(2) : null, verdict: verdict(kills, deaths),
    bot_damage_to_death_median_s: median(botSurvival), bot_damage_samples: botSurvival.length, maps: perMap,
    limits: 'Pilot-victim events only, not scoreboards. Bot damage-to-death spans are clean single-attacker episodes only. Compare like maps; small samples are exploratory.'};
}

function main() {
  const args = process.argv.slice(2);
  const cohorts = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--label') { cohorts.push({label: args[++i], files: []}); continue; }
    if (!cohorts.length) cohorts.push({label: 'session', files: []});
    cohorts.at(-1).files.push(args[i]);
  }
  if (!cohorts.length) throw new Error('Pass one or more analysis.json files');
  for (const c of cohorts) {
    const s = summarize(c.files.map(f => JSON.parse(fs.readFileSync(f, 'utf8'))));
    console.log(`\n== ${c.label}: K/D ${s.kd ?? 'n/a'} (${s.kills}/${s.deaths}) over ${s.minutes} min -> ${s.verdict}; bot damage-to-death median ${s.bot_damage_to_death_median_s?.toFixed(3) ?? 'n/a'} s (n=${s.bot_damage_samples})`);
    for (const m of s.maps) console.log(`   ${m.map.padEnd(18)} K/D ${String(m.kd ?? 'n/a').padStart(5)}  ${m.kills}/${m.deaths}  kills/10min ${m.kills_per_10min}  -> ${m.verdict}`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
