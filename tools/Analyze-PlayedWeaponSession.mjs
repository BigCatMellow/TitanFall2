// Offline analysis. No game launches, uploads, account IDs or raw-log exports.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {analyzeNotes,parseNote} from './weapon-notes.mjs';
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
const median=a=>{const b=[...a].sort((x,y)=>x-y);return b.length?(b[Math.floor((b.length-1)/2)]+b[Math.floor(b.length/2)])/2:null;};
const pct=(n,d)=>d?Math.round(n/d*10000)/100:null;
const speed=e=>Math.hypot(+e.vvx,+e.vvy);
const key=e=>`${e.epoch}|${e.t}|${e.slot}`;
const nav=new Set(['pursue','recover','embark','retreat','patrol']);
function damageGroups(deaths){
  const groups=new Map();for(const d of deaths){const k=JSON.stringify([d.map,d.mode,d.gun,d.attacker_kind,d.victim_kind,d.mods,d.config,d.range_bucket,d.hitgroups,d.critical_scales]);if(!groups.has(k))groups.set(k,[]);groups.get(k).push(d);}
  return [...groups.values()].map(a=>({map:a[0].map,mode:a[0].mode,gun:a[0].gun,attacker_kind:a[0].attacker_kind,victim_kind:a[0].victim_kind,mods:a[0].mods,config:a[0].config,range_bucket:a[0].range_bucket,hitgroups:a[0].hitgroups,critical_scales:a[0].critical_scales,n:a.length,median_s:median(a.map(d=>d.damage_span_s)),min_s:Math.min(...a.map(d=>d.damage_span_s)),max_s:Math.max(...a.map(d=>d.damage_span_s))}));
}
export function markLowProgress(rows){
  const groups=new Map();for(const r of rows){r.low=false;const k=r.epoch+'|'+r.slot;if(!groups.has(k))groups.set(k,[]);groups.get(k).push(r);}
  for(const group of groups.values())for(let i=1;i<group.length;i++){
    const r=group[i];if(r.alive!=='1'||r.titan!=='0'||!nav.has(r.state))continue;
    let continuous=true;
    for(let j=i-1;j>=0;j--){const p=group[j];
      if(p.id!==r.id||p.alive!=='1'||p.titan!=='0'||+group[j+1].t-(+p.t)>2.1||+group[j+1].t<=+p.t)break;
      if(!nav.has(p.state))continuous=false;
      const age=+r.t-(+p.t);
      if(age>=10){r.low=age<=13&&continuous&&Math.hypot(+r.x-(+p.x),+r.y-(+p.y))<50;
        if(r.low){r.low_jump_fraction=(+r.jumps-(+p.jumps))/(+r.commands-(+p.commands));r.low_yaw_delta=+r.yaw_travel-(+p.yaw_travel);}break;}
    }
  }return rows;
}
export function analyzePlayed(events,log){
  const measured=analyzeNotes(events),rounds=[],hits=new Map(),posts=new Map();let context=0;
  for(const e of events){
    if(e.type==='WNOTE_CONTEXT'){context++;rounds.push({context,map:e.map,mode:e.mode,first_damage_t:Infinity,last_damage_t:0,human_pilot_kills_credited:0,human_pilot_deaths_recorded:0,unattributed_deaths:0,human_guns:{},fatal_bot_speeds:[],human_incoming_fatal_guns:{}});}
    const r=rounds.at(-1);if(!r)continue;
    if(e.type==='WNOTE_HIT'){hits.set(context+'|'+e.event,e);r.first_damage_t=Math.min(r.first_damage_t,+e.t);r.last_damage_t=Math.max(r.last_damage_t,+e.t);}
    if(e.type==='WNOTE_POST')posts.set(context+'|'+e.event,e);
    if(e.type==='WNOTE_DEATH'){
      r.last_damage_t=Math.max(r.last_damage_t,+e.t);
      const h=hits.get(context+'|'+e.event),post=posts.get(context+'|'+e.event);
      if(!h||h.victim!==e.victim||h.life!==e.life||post?.hp_after!=='0'){r.unattributed_deaths++;continue;}
      if(h.vkind==='human'){r.human_pilot_deaths_recorded++;r.human_incoming_fatal_guns[h.gun]=(r.human_incoming_fatal_guns[h.gun]||0)+1;}
      if(h.akind==='human'&&h.vkind==='bot'&&h.attacker!==h.victim&&h.ateam!==h.vteam){
        r.human_pilot_kills_credited++;r.human_guns[h.gun]=(r.human_guns[h.gun]||0)+1;r.fatal_bot_speeds.push(speed(h));
      }
    }
  }
  const players=new Map(),frameHumans=new Map(),traces=new Map(),combats=new Map(),actions=new Map(),ready=[],skills=[],starts=[];
  let frame=null;const runtimeErrors=[];
  for(const line of log.split(/\r?\n/)){
    if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked/.test(line))runtimeErrors.push(true);
    const note=parseNote(line);if(note?.type==='WNOTE_CONTEXT'){if(frame?.map!==note.map)throw new Error('Native frame map differs from recorder context');starts.push({map:note.map,epoch:frame?.epoch,start_t:+frame?.t});continue;}
    const m=line.match(/^(?:\[[^\]\r\n]*\]\s*)*(BOT_FRAME|BOT_PLAYER|BOT_TRACE|BOT_COMBAT|BOT_ACTION|BOT_READY|BOT_SKILL)(?:\s|$)/);if(!m)continue;
    const f=fields(line);
    if(m[1]==='BOT_FRAME')frame=f;
    if(m[1]==='BOT_PLAYER'){players.set(key(f),f);if(f.bot==='0')frameHumans.set(f.epoch+'|'+f.t,f);}
    if(m[1]==='BOT_TRACE')traces.set(key(f),f);
    if(m[1]==='BOT_COMBAT')combats.set(key(f),f);
    if(m[1]==='BOT_ACTION')actions.set(key(f),f);
    if(m[1]==='BOT_READY'&&frame)ready.push({...f,epoch:frame.epoch});
    if(m[1]==='BOT_SKILL')skills.push(f);
  }
  if(starts.length!==rounds.length)throw new Error('Recorder/native context count mismatch');
  for(let n=0;n<rounds.length;n++){
    const r=rounds[n],start=starts[n];if(r.map!==start.map||!start.epoch)throw new Error('Ambiguous native epoch association');
    r.epoch=+start.epoch;r.telemetry_window_start=start.start_t;r.telemetry_window_end=r.last_damage_t;
    const inWindow=e=>e.epoch===start.epoch&&+e.t>=start.start_t&&+e.t<=r.last_damage_t;
    const rows=[...players.values()].filter(e=>e.bot==='1'&&inWindow(e)).map(p=>({...p,...traces.get(key(p)),combat:combats.get(key(p)),action:actions.get(key(p))}));
    markLowProgress(rows);
    const pilots=rows.filter(e=>e.alive==='1'&&e.titan==='0'&&e.state);
    const low=pilots.filter(e=>e.low),engage=pilots.filter(e=>e.visible==='1'&&e.state==='engage');
    const human=engage.filter(e=>{const h=frameHumans.get(e.epoch+'|'+e.t);return h?.alive==='1'&&h.titan==='0'&&h.id===e.target;});
    const holds=engage.filter(e=>e.combat?.active==='1'&&e.combat.tactic.endsWith('hold'));
    const humanHolds=human.filter(e=>e.combat?.active==='1'&&e.combat.tactic.endsWith('hold'));
    const grouped=new Map();for(const row of low){const cell=[Math.round(+row.x/128)*128,Math.round(+row.y/128)*128,Math.round(+row.z/64)*64].join(',');if(!grouped.has(cell))grouped.set(cell,{cell,samples:0,slots:new Set()});const c=grouped.get(cell);c.samples++;c.slots.add(row.slot);}
    const previous=new Map();let blocked=0,jumps=0,commands=0,holdPairs=0,blockedHoldPairs=0;
    for(const row of rows){const prev=previous.get(row.slot);previous.set(row.slot,row);
      if(!prev||prev.id!==row.id||prev.alive!=='1'||row.alive!=='1'||prev.titan!=='0'||row.titan!=='0'||+row.t-(+prev.t)>2.1||+row.t<=+prev.t)continue;
      const dc=+row.commands-(+prev.commands),dj=+row.jumps-(+prev.jumps);if(dc>0&&dj>=0&&dj<=dc){commands+=dc;jumps+=dj;}
      const b=+row.combat?.blocked_steps-(+prev.combat?.blocked_steps);if(b>=0)blocked+=b;
      if(row.combat?.active==='1'&&row.combat.tactic.endsWith('hold')){holdPairs++;if(b>0)blockedHoldPairs++;}
    }
    const rr=ready.filter(inWindow),sk=skills.filter(inWindow),weapons={};for(const e of pilots)if(e.combat?.active==='1')weapons[e.combat.weapon]=(weapons[e.combat.weapon]||0)+1;
    const pressure=new Map();for(const e of human){const k=e.epoch+'|'+e.t;pressure.set(k,(pressure.get(k)||0)+1);}
    r.movement={live_pilot_samples:pilots.length,navigation_low_samples:low.length,navigation_low_percent:pct(low.length,pilots.length),low_with_over_720deg_yaw:low.filter(e=>e.low_yaw_delta>=720).length,low_with_jump_command_fraction_over_20pct:low.filter(e=>e.low_jump_fraction>0.2).length,hotspots:[...grouped.values()].sort((a,b)=>b.samples-a.samples).slice(0,6).map(c=>({...c,slots:[...c.slots].sort((a,b)=>+a-+b)})),visible_engage_samples:engage.length,range_hold_samples:holds.length,range_hold_speed_median:median(holds.map(e=>+e.speed)),range_hold_under50_percent:pct(holds.filter(e=>+e.speed<50).length,holds.length),hold_samples_with_contiguous_previous:holdPairs,hold_samples_with_recent_blocked_step:blockedHoldPairs,hold_recent_blocked_percent:pct(blockedHoldPairs,holdPairs),blocked_step_counter_increments:blocked,jump_commands_observed:jumps,commands_observed:commands,jump_command_percent:pct(jumps,commands)};
    r.pressure={visible_human_engage_samples:human.length,human_hold_samples:humanHolds.length,human_hold_speed_median:median(humanHolds.map(e=>+e.speed)),human_hold_under50_percent:pct(humanHolds.filter(e=>+e.speed<50).length,humanHolds.length),human_vertical_gap_over180_percent:pct(human.filter(e=>Math.abs(+e.tz-(+e.z))>180).length,human.length),simultaneous_visible_human_max:pressure.size?Math.max(...pressure.values()):0,human_visible_frames:pressure.size,frames_with_2plus_visible_engagers:[...pressure.values()].filter(v=>v>=2).length};
    r.abilities={ready_observations:rr.length,tactical_classes:[...new Set(rr.map(e=>e.tactical))],tactical_nonzero_shot_counter_observations:rr.filter(e=>+e.tactical_shots>0).length,ordnance_classes:[...new Set(rr.map(e=>e.ordnance))],ordnance_nonzero_shot_counter_observations:rr.filter(e=>+e.ordnance_shots>0).length,
      // bot_skill_use presses that the readiness gate allowed (requests, not confirmed casts).
      skill_starts:sk.length,skill_reasons:sk.reduce((o,e)=>{for(const k of [e.tactical,e.ordnance])if(k&&k!=='-')o[k]=(o[k]||0)+1;return o;},{}),skill_by_archetype:sk.reduce((o,e)=>{o[e.archetype]=(o[e.archetype]||0)+1;return o;},{})};
    r.bot_active_weapon_samples=weapons;
    r.fatal_bot_speed_median=median(r.fatal_bot_speeds);r.fatal_bot_speed_under50_percent=pct(r.fatal_bot_speeds.filter(v=>v<50).length,r.fatal_bot_speeds.length);delete r.fatal_bot_speeds;
    const kills=measured.deaths.filter(d=>d.context===r.context&&d.clean_health_episode&&d.attacker_kind==='human'&&d.victim_kind==='bot');
    r.qualifying_human_damage_groups=damageGroups(kills);
    r.qualifying_human_episodes=kills.length;
    r.qualifying_bot_to_human_groups=damageGroups(measured.deaths.filter(d=>d.context===r.context&&d.clean_health_episode&&d.attacker_kind==='bot'&&d.victim_kind==='human'));
    const rawHuman=[...hits.entries()].filter(([k,h])=>k.startsWith(r.context+'|')&&h.akind==='human'&&h.vkind==='bot'&&h.ateam!==h.vteam);
    r.human_damage_sources=[...new Set(rawHuman.map(([,h])=>h.gun))].map(gun=>{const a=rawHuman.filter(([,h])=>h.gun===gun),positive=a.filter(([k,h])=>posts.has(k)&&+posts.get(k).hp_after<+h.hp);return {gun,damage_events:a.length,paired_positive_events:positive.length,paired_health_loss:positive.reduce((sum,[k,h])=>sum+Math.max(0,+h.hp-(+posts.get(k).hp_after)),0),damage_event_range_median:median(a.map(([,h])=>+h.range)),actual_mod_stacks:[...new Set(a.map(([,h])=>h.mods))]};});
  }
  return {schema_version:1,death_records:measured.death_records,qualifying_health_episodes:measured.clean_health_episodes,logger_errors:measured.logger_errors,runtime_error_markers:runtimeErrors.length,exclusion_counts:measured.exclusion_counts,rounds,limits:'Pilot-victim damage/death only: not scoreboard totals, Titan deaths, shots, accuracy or trigger/first-shot TTK. Kill credit is the matching lethal event, not a new scoreboard hook. Native analysis window starts at the telemetry frame preceding Playing and ends at the last recorded damage/death; not exact winner/end-state markers. Two-second overlapping samples and contiguous counter deltas are not independent incidents or action-success counts; short deaths may be unsampled. Hold/step-block associations do not prove why an individual bot died. Different maps, guns, ranges, hitgroups, modifiers and play styles are not controlled comparisons. No visual watching or causal balance conclusion. Only derived aggregate output is published.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];for(const k of ['--session','--profile','--out'])if(!args.includes(k))throw new Error('Missing '+k);
  const session=get('--session'),out=get('--out'),meta=JSON.parse(fs.readFileSync(path.join(session,'session.json'),'utf8').replace(/^\uFEFF/,'')),summary=JSON.parse(fs.readFileSync(path.join(session,'summary.json'),'utf8'));
  if(meta.mode!=='normal_play'||summary.state!=='complete')throw new Error('Use a completed normal-play session');
  const eventBytes=fs.readFileSync(path.join(session,'events.jsonl')),raw=fs.readFileSync(path.join(get('--profile'),'logs',summary.source_log));
  const events=eventBytes.toString('utf8').trim().split('\n').map(JSON.parse),report=analyzePlayed(events,raw.toString('utf8'));
  if(report.death_records!==summary.death_records||report.qualifying_health_episodes!==summary.clean_health_episodes)throw new Error('Notebook replay mismatch');
  report.provenance={session:path.basename(session),native_sha256:meta.native_sha256,event_sha256:crypto.createHash('sha256').update(eventBytes).digest('hex'),private_log_sha256:crypto.createHash('sha256').update(raw).digest('hex'),core:meta.core};
  fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'analysis.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({death_records:report.death_records,qualifying:report.qualifying_health_episodes,rounds:report.rounds.map(r=>({map:r.map,kills:r.human_pilot_kills_credited,deaths:r.human_pilot_deaths_recorded,movement:r.movement,pressure:r.pressure,abilities:r.abilities}))},null,2));
}
