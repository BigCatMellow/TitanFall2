// Private-log-only, read-only WeaponNotes concordance. Counts are NOT causal
// grenade or kill attribution. No entity handles or event IDs leave the report.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const MARK=/^(?:\[[^\]\r\n]*\]\s*)*(WNOTE_CONTEXT|WNOTE_HIT|WNOTE_POST|WNOTE_GAP|WNOTE_DEATH|WNOTE_ERROR|BT_FRAG_DAMAGE|BT_FRAG_DAMAGE_ERROR)(?:\s|$)/;
const num=x=>typeof x==='string'&&x!==''&&Number.isFinite(Number(x))?Number(x):null;
const id=x=>typeof x==='string'&&/^-?\d+$/.test(x)&&Number.isSafeInteger(Number(x))&&Number(x)!==-1?Number(x):null;
const event=x=>{const n=id(x);return n!==null&&n>=0?n:null};
const validMap=m=>/^mp_[a-z0-9_]+$/.test(m||'');
function parse(line) {
  const m=line.match(MARK);if(!m)return null;
  const f=Object.create(null);
  for(const p of line.slice(m[0].length).matchAll(/(?:^|\s)([a-z][a-z_0-9]*)=([^\s]+)/g))f[p[1]]=p[2];
  return {type:m[1],...f};
}
const relation=(a,b,ta,tb)=>a===b?'self':ta===tb?'friendly':'enemy';
const keys=h=>[h.attacker,h.victim,h.relation].join('|');
const newCounts=()=>({damage_callbacks:0,eligible_notebook_hits:0,
  uniquely_matched:0,ambiguous:0,unmatched:0,
  post_health_decrease_consistent:0,fatal_notebook_record_consistent:0,missing_clean_post:0});
export function compareFragNotebook(text) {
  const segments=[];let current=null,rawProbe=0,unscoped=0,probeErrors=0,notebookErrors=0,gapsSeen=0;
  for(const line of text.split(/\r?\n/)){
    const e=parse(line);if(!e)continue;
    if(e.type==='BT_FRAG_DAMAGE_ERROR'){probeErrors++;continue;}
    if(e.type==='WNOTE_ERROR'){notebookErrors++;continue;}
    if(e.type==='WNOTE_CONTEXT'){
      current={map:validMap(e.map)?e.map:null,damage:[],hits:[],posts:new Map(),deaths:new Map(),gaps:new Set()};
      segments.push(current);continue;
    }
    if(e.type==='BT_FRAG_DAMAGE'){
      rawProbe++;
      const a=id(e.attacker),v=id(e.victim),t=num(e.t),d=num(e.damage);
      if(e.schema!=='1'||a===null||v===null||t===null||t<0||d===null||d<=0
        ||!['self','friendly','enemy'].includes(e.relation)||(a===v)!==(e.relation==='self')
        ||!current||!current.map||current.map!==e.map){unscoped++;continue;}
      current.damage.push({attacker:a,victim:v,t,relation:e.relation});continue;
    }
    if(!current||!current.map)continue;
    if(e.type==='WNOTE_HIT'){
      const a=id(e.attacker),v=id(e.victim),t=num(e.t),event=eventId(e.event);
      const life=eventId(e.life),hp=num(e.hp),ta=num(e.ateam),tv=num(e.vteam);
      if([a,v,t,event,life,hp,ta,tv].some(x=>x===null)||t<0||hp<0
        ||e.gun!=='mp_weapon_frag_grenade'||e.akind!=='bot'||!['bot','human'].includes(e.vkind)
        ||e.atitan!=='false'||e.force!=='false'||ta<=0||tv<=0)continue;
      current.hits.push({attacker:a,victim:v,t,event,life,hp,relation:relation(a,v,ta,tv)});
    } else if(e.type==='WNOTE_POST'||e.type==='WNOTE_DEATH'){
      const k=eventId(e.event),v=id(e.victim),life=eventId(e.life),t=num(e.t);
      if([k,v,life,t].some(x=>x===null)||t<0)continue;
      (e.type==='WNOTE_POST'?current.posts:current.deaths).set(k,{victim:v,life,t,
        hp:e.type==='WNOTE_POST'?num(e.hp_after):null});
    } else if(e.type==='WNOTE_GAP'){
      gapsSeen++;
      const k=eventId(e.event);if(k!==null)current.gaps.add(k);
    }
  }
  const counts=newCounts(),groups=new Map();
  for(const s of segments){
    if(!s.map)continue;
    if(!groups.has(s.map))groups.set(s.map,newCounts());
    const g=groups.get(s.map);
    for(const c of [g,counts]){
      c.damage_callbacks+=s.damage.length;
      c.eligible_notebook_hits+=s.hits.length;
    }
    const index=new Map();
    for(const h of s.hits){const k=keys(h);if(!index.has(k))index.set(k,[]);index.get(k).push(h);}
    const candidates=s.damage.map(d=>(index.get(keys(d))||[]).filter(h=>Math.abs(h.t-d.t)<=0.05));
    const competitors=new Map();
    for(const matches of candidates)for(const h of matches)competitors.set(h,(competitors.get(h)||0)+1);
    for(let i=0;i<s.damage.length;i++){
      const matches=candidates[i];
      const className=matches.length>1||(matches.length===1&&competitors.get(matches[0])>1)
        ?'ambiguous':matches.length===1?'uniquely_matched':'unmatched';
      for(const c of [g,counts])c[className]++;
      if(className!=='uniquely_matched')continue;
      const h=matches[0],p=s.posts.get(h.event),d=s.deaths.get(h.event);
      const post=!s.gaps.has(h.event)&&p&&p.victim===h.victim&&p.life===h.life
        &&p.t>=h.t&&p.t-h.t<=0.5&&p.hp!==null&&p.hp>=0&&p.hp<h.hp;
      for(const c of [g,counts])c[post?'post_health_decrease_consistent':'missing_clean_post']++;
      if(post&&p.hp===0&&d&&d.victim===h.victim&&d.life===h.life
        &&d.t>=h.t&&d.t-h.t<=0.05)
        for(const c of [g,counts])c.fatal_notebook_record_consistent++;
    }
  }
  return {schema_version:1,probe_callbacks_total:rawProbe,unscoped_or_invalid_probe_callbacks:unscoped,
    probe_errors_logged:probeErrors,notebook_errors_logged:notebookErrors,
    notebook_gap_markers_logged:gapsSeen,...counts,
    maps:[...groups].sort(([a],[b])=>a.localeCompare(b)).map(([map,c])=>({map,...c})),
    status:probeErrors?'probe_error_incomplete':notebookErrors?'notebook_error_incomplete'
      :gapsSeen?'notebook_gap_review_required':unscoped?'context_or_invalid_callbacks_review_required'
      :counts.uniquely_matched?'concordant_callbacks_not_causation':'no_unique_matches_cannot_infer_no_damage',
    limits:[
      'Requires a WNOTE_CONTEXT segment and map, exact Squirrel encoded attacker/victim handles, same self/friendly/enemy relation, and within 0.05 seconds.',
      'More than one candidate either way is ambiguous and excluded; signed encoded handles are accepted but never exported.',
      'WNOTE_POST health decrease and WNOTE_DEATH with matching victim/life/event are concordant observations, not proof a grenade caused damage or death. Overlapping hits remain possible.',
      'WNOTE_GAP or missing/invalid post disqualifies post concordance. Never equate projectile, inflictor and native BOT_FRAG_INPUT identifiers.',
      'No raw IDs, timestamps, positions, lines or event IDs are written. No matched active-pilot exposure, verified throws, trajectories, explosions, or frag kill credit.',
      'WNOTE_ERROR markers indicate incomplete notebook evidence and WNOTE_GAP indicates overwritten pending events; do not treat missing health-post records as negative damage results.',
      'No matches may indicate missing WNOTE_CONTEXT, disabled logs/probe, ambiguous rapid hits, sparse timing, or genuinely absent qualifying callbacks.',
    ]};
}
function eventId(x){return event(x);}
function main(argv){
  const opt=k=>{const i=argv.indexOf(k);return i<0?null:argv[i+1]};
  const input=opt('--log'),output=opt('--out');
  if(!input||argv.length!==(output?4:2))throw Error('Usage: node tools/Compare-FragNotebook.mjs --log PRIVATE.log [--out PRIVATE.json]');
  const report=compareFragNotebook(fs.readFileSync(input,'utf8'));
  if(output){
    if(path.resolve(output)===path.resolve(input))throw Error('Cannot overwrite source log');
    fs.mkdirSync(path.dirname(output),{recursive:true});
    fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
  }
  console.log(JSON.stringify(report,null,2));
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2));
