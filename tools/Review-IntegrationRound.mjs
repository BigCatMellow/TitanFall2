import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {reviewRouteStudy} from './Review-RouteStudy.mjs';
import {parseBotTrialLog} from './Analyze-BotAITrial.mjs';
import {analyzeFragLog} from './Analyze-FragLifecycle.mjs';
import {compareFragNotebook} from './Compare-FragNotebook.mjs';
export function reviewIntegrationRound(lines,options={}){
  const r=reviewRouteStudy(lines,{integration:true,...options});
  const header=lines.find(l=>l.includes((options.marker||'MAP_SURVEY_INTEGRATION')+' '));
  const start=Number(header.match(/\bt=([\d.]+)/)?.[1]);
  const end=start+r.duration_s;
  if(!Number.isFinite(start))throw Error('Missing integration clock');
  const window=lines.filter(l=>{
    if(l.includes('WNOTE_CONTEXT '))return true;
    // These fault records have no engine timestamp. Retain them from the
    // whole fresh-process log rather than silently certifying a clean window.
    if(/\b(?:WNOTE_GAP|WNOTE_ERROR|WNOTE_FIRE_ERROR|BT_FRAG_AWARE_ERROR|BT_FRAG_DAMAGE_ERROR|BT_FRAG_PROBE_ERROR)\b/.test(l))return true;
    const m=l.match(/(?:^|\s)t=([\d.]+)/);return m&&+m[1]>=start&&+m[1]<=end+0.1;
  }).join('\n');
  const frag=analyzeFragLog(window);
  return {...r,diagnostics:parseBotTrialLog(window),
    additive_frag_damage:{probe_kind:'additive_damage_only_no_lifecycle_override',maps:frag.damage_maps,errors:frag.damage_probe_errors_logged,status:frag.damage_probe_status},
    notebook_concordance:compareFragNotebook(window),
    diagnostic_fault_scope:'Clockless fault/gap markers retained conservatively from the whole fresh-process log; exact match-window attribution is unavailable.',
    limits:'Frozen integrated native, bot-only Full observer rounds. Low-progress windows overlap and are not independent failures. Weapon callback/shot parameters and sampled magazine decreases are proxies, not validated accuracy or first-shot TTK. Frag entity sampling can miss very short-lived/invalid-owner projectiles; outcomes overlap and near-end cases are censored. Cell comparisons share a frozen integrated native. Diagnostics measure logged inputs and decisions, not confirmed traversal or human difficulty. Additive damage callbacks are separate from health loss/deaths and lifecycle stage instrumentation is not installed. Low-clearance/nearest switches can remain unexercised; inspect channels before interpreting zero counts.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  if(path.resolve(get('--log'))===path.resolve(get('--out')))throw Error('Cannot overwrite source');
  const raw=fs.readFileSync(get('--log')),r=reviewIntegrationRound(raw.toString('utf8').split(/\r?\n/));
  r.log_sha256=crypto.createHash('sha256').update(raw).digest('hex');
  fs.writeFileSync(get('--out'),JSON.stringify(r,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify({map:r.map,cell:r.cell,low:r.low_progress_percent,frags:r.frag.observed_projectiles,errors:r.error_markers}));
}
