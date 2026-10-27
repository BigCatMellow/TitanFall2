import fs from 'node:fs';
import path from 'node:path';
export const metric='first_positive_health_damage_to_death_s';
export function parseNote(line){
  const m=line.match(/^(?:\[[^\]\r\n]*\]\s*)*(WNOTE_[A-Z_]+)(?:\s|$)/);if(!m)return null;
  return {type:m[1],...Object.fromEntries([...line.slice(m.index).matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]))};
}
const median=a=>{const s=[...a].sort((a,b)=>a-b);return s.length?(s[Math.floor((s.length-1)/2)]+s[Math.floor(s.length/2)])/2:null};
const rangeBucket=n=>!Number.isFinite(n)||n<0?'unknown':n<500?'0-499u':n<1000?'500-999u':n<2000?'1000-1999u':'2000u+';
export function analyzeNotes(events){
  let context=0,meta=null;const hits=new Map(),episodes=new Map(),deaths=[],errors=[];
  const key=e=>`${context}|${e.victim}|${e.life}`;
  for(const e of events){
    if(e.type==='WNOTE_CONTEXT'){context++;meta=e;continue;}
    if(e.type==='WNOTE_ERROR'){errors.push(e);continue;}
    if(e.type==='WNOTE_LIFE'){for(const k of episodes.keys())if(k.startsWith(`${context}|${e.victim}|`))episodes.delete(k);continue;}
    if(e.type==='WNOTE_HIT'){
      const h={...e,context,meta,after:null,gap:false};hits.set(`${context}|${e.event}`,h);continue;
    }
    if(e.type==='WNOTE_GAP'){const h=hits.get(`${context}|${e.event}`);if(h)h.gap=true;continue;}
    if(e.type==='WNOTE_POST'){
      const h=hits.get(`${context}|${e.event}`);if(!h||h.victim!==e.victim||h.life!==e.life)continue;
      h.after=Number(e.hp_after);if(!Number.isFinite(h.after)||h.after<0||h.after>=+h.hp)continue;
      const k=key(h);let a=episodes.get(k)||[];
      // A fully observed return to full health begins a new damage episode.
      if(a.length&&+h.hp>=+h.max_hp&&a.at(-1).after<+h.max_hp)a=[];
      a.push(h);episodes.set(k,a);continue;
    }
    if(e.type==='WNOTE_DEATH'){
      const a=episodes.get(key(e))||[];episodes.delete(key(e));
      const reasons=[];const first=a[0],last=a.at(-1);
      if(!first||!last||last.event!==e.event||last.after!==0)reasons.push('missing_complete_health_sequence');
      if(first){
        if(!first.meta)reasons.push('missing_context');
        if(+first.hp!==+first.max_hp||+first.max_hp!==100)reasons.push('not_full_100hp_start');
        if(a.some(h=>h.gap||h.after===null))reasons.push('missing_post_damage');
        if(new Set(a.map(h=>`${h.attacker}|${h.attacker_life}`)).size!==1)reasons.push('multiple_attackers');
        if(new Set(a.map(h=>h.gun)).size!==1)reasons.push('multiple_weapons');
        if(new Set(a.map(h=>h.mods)).size!==1||new Set(a.map(h=>h.config)).size!==1)reasons.push('changed_configuration');
        if(a.some(h=>h.mods==='unknown'))reasons.push('unknown_mod_stack');
        if(a.some(h=>!['human','bot'].includes(h.akind)||!['human','bot'].includes(h.vkind)||h.atitan==='true'))reasons.push('not_pilot_vs_pilot');
        if(a.some(h=>h.force==='true'||h.attacker===h.victim||h.ateam===h.vteam))reasons.push('force_self_or_friendly_damage');
        if(a.some(h=>h.gun==='unknown'||!h.gun.startsWith('mp_weapon_')))reasons.push('non_weapon_or_unknown_source');
        for(let i=1;i<a.length;i++){
          if(+a[i].hp>a[i-1].after+0.5)reasons.push('healing_observed');
          if(+a[i].hp<a[i-1].after-0.5)reasons.push('unaccounted_health_loss');
          if(+a[i].t<+a[i-1].t)reasons.push('clock_regression');
        }
      }
      const span=first?+e.t-(+first.t):null;if(span!==null&&span<0)reasons.push('clock_regression');
      deaths.push({context,map:meta?.map??'unknown',mode:meta?.mode??'unknown',gun:first?.gun??'unknown',
        attacker_kind:first?.akind??'unknown',victim_kind:first?.vkind??'unknown',mods:first?.mods??'unknown',config:first?.config??'unknown',
        range_bucket:first?rangeBucket(+first.range):'unknown',range_units_first:first?+first.range:null,
        metric,damage_span_s:span,damage_events:a.length,health_lost:a.reduce((n,h)=>n+(+h.hp-h.after),0),
        hitgroups:[...new Set(a.map(h=>h.hitgroup))].sort(),critical_scales:[...new Set(a.map(h=>h.crit_scale))].sort(),
        attacker_speed_first:first?Math.hypot(+first.avx,+first.avy):null,victim_speed_first:first?Math.hypot(+first.vvx,+first.vvy):null,
        clean_health_episode:reasons.length===0,exclusions:[...new Set(reasons)],single_tick_span:span!==null&&span<=(+meta?.tick||0.016667)});
    }
  }
  const grouped=new Map();
  for(const d of deaths.filter(d=>d.clean_health_episode)){
    const k=JSON.stringify([d.map,d.mode,d.gun,d.attacker_kind,d.victim_kind,d.mods,d.config,d.range_bucket,d.hitgroups,d.critical_scales]);
    if(!grouped.has(k))grouped.set(k,[]);grouped.get(k).push(d);
  }
  const groups=[...grouped.values()].map(a=>({map:a[0].map,mode:a[0].mode,gun:a[0].gun,attacker_kind:a[0].attacker_kind,victim_kind:a[0].victim_kind,mods:a[0].mods,config:a[0].config,range_bucket:a[0].range_bucket,hitgroups:a[0].hitgroups,critical_scales:a[0].critical_scales,n:a.length,metric,median_s:median(a.map(d=>d.damage_span_s)),min_s:Math.min(...a.map(d=>d.damage_span_s)),max_s:Math.max(...a.map(d=>d.damage_span_s))}));
  const exclusions={};for(const d of deaths)for(const reason of d.exclusions)exclusions[reason]=(exclusions[reason]||0)+1;
  return {schema_version:1,metric,death_records:deaths.length,clean_health_episodes:deaths.filter(d=>d.clean_health_episode).length,logger_errors:errors.length,exclusion_counts:exclusions,groups,deaths,
    limits:'Damage-to-death spans, NOT first-shot TTK, trigger-to-kill or accuracy. Damage events are not shots. Full-HP/single-attacker checks cannot rule out unobserved healing/buffs/shields; hitgroups remain numeric. Do not pool humans/bots, modes, maps, mods, configs, ranges or critical-hit contexts. Synthetic validation stays separate. Small n is exploratory.'};
}
export function writeNotes(out,events,metadata={}){
  fs.mkdirSync(out,{recursive:true});const result={...metadata,...analyzeNotes(events)};
  fs.writeFileSync(path.join(out,'summary.json'),JSON.stringify(result,null,2)+'\n');
  const md=['# Recorded weapon notes','',result.limits,'',`Deaths: ${result.death_records}; qualifying health episodes: ${result.clean_health_episodes}; recorder errors: ${result.logger_errors}.`,'','| Map/mode | Weapon | Actors | Range | Samples | Median damage span |','|---|---|---|---|---:|---:|',...result.groups.map(g=>`| ${g.map}/${g.mode} | ${g.gun} | ${g.attacker_kind}→${g.victim_kind} | ${g.range_bucket} | ${g.n} | ${g.median_s.toFixed(3)} s |`),'','Groups also remain separated by actual modifiers, configuration, hitgroups and critical scales in summary.json. ADS state and missed shots are not observed.'];
  fs.writeFileSync(path.join(out,'NOTES.md'),md.join('\n')+'\n');return result;
}
