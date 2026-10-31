import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import{fileURLToPath}from'node:url';
import{reviewIntegrationRound}from'./Review-IntegrationRound.mjs';
const definition=JSON.parse(fs.readFileSync(new URL('../automation/awareness-v31-cells.json',import.meta.url)));
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
export function awarenessEvidence(lines,start=-Infinity,end=Infinity){
 const counts={visible:0,memory:0,search:0,patrol:0};let changedHiddenGoals=0,comparisons=0,seenPatrolTransitions=0;const previous=new Map();
 for(const line of lines){if(!line.includes('BOT_AWARENESS '))continue;const f=fields(line);if(+f.t<start||+f.t>end)continue;if(!Object.hasOwn(counts,f.mode))throw Error('Unknown awareness mode');counts[f.mode]++;
  const k=f.epoch+':'+f.slot,p=previous.get(k);const hidden=['memory','search'].includes(f.mode),oldHidden=p&&['memory','search'].includes(p.mode);
  if(hidden&&(!Number.isFinite(+f.seen_age)||+f.seen_age<0))throw Error('Invalid memory age');
  // Exact logged observation time distinguishes a real refresh from hidden drift.
  if(hidden&&oldHidden&&p.target===f.target&&+f.t>+p.t&&Number.isFinite(+f.seen_at)&&f.seen_at===p.seen_at){comparisons++;if(['gx','gy','gz'].some(key=>Math.abs(+f[key]-+p[key])>0.11))changedHiddenGoals++;}
  if(f.mode==='patrol'&&p&&['memory','search'].includes(p.mode))seenPatrolTransitions++;
  previous.set(k,f);
 }
 return{mode_log_samples:counts,continuous_memory_comparisons:comparisons,changed_hidden_goal_comparisons:changedHiddenGoals,logged_memory_to_patrol:seenPatrolTransitions};
}
export function reviewAwareness(lines){
 const r=reviewIntegrationRound(lines,{definition,marker:'MAP_SURVEY_AWARENESS',cohort:'awareness_v31'});const h=fields(lines.find(l=>l.includes('MAP_SURVEY_AWARENESS '))),start=+h.t,end=start+r.duration_s;
 const evidence=awarenessEvidence(lines,start,end);let scaleHits=0,scalingErrors=0;
 for(const l of lines){if(!l.includes('BT_FRAG_SELF_SCALE '))continue;const f=fields(l);if(+f.t<start||+f.t>end)continue;scaleHits++;if(+f.scale!==0.25||Math.abs(+f.after-+f.before*0.25)>0.01)scalingErrors++;}
 const traces=lines.filter(l=>l.includes('BOT_TRACE ')).map(fields).filter(f=>+f.t>=start&&+f.t<=end&&f.state==='patrol');
 return{...r,awareness:evidence,patrol_trace_samples:traces.length,frag_self_scaling:{hits:scaleHits,errors:scalingErrors},limits:r.limits+' Awareness modes are transitions / spaced samples, not time fractions. Frozen hidden goals do not prove human fairness or absence of other sensing channels. Patrol is included in navigation low-progress checks. Keep bot-observer matches separate from human feedback.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const raw=fs.readFileSync(process.argv[2]),r=reviewAwareness(raw.toString('utf8').split(/\r?\n/));r.log_sha256=crypto.createHash('sha256').update(raw).digest('hex');fs.writeFileSync(process.argv[3],JSON.stringify(r,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({map:r.map,cell:r.cell,duration:r.duration_s,low:r.low_progress_percent,awareness:r.awareness,errors:r.error_markers}));
}
