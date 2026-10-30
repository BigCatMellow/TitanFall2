import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
import {reviewIntegrationRound} from './Review-IntegrationRound.mjs';
const definition=JSON.parse(fs.readFileSync(new URL('../automation/tuning-v29-cells.json',import.meta.url)));
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
export function reviewTuningRound(lines){
 const base=reviewIntegrationRound(lines,{definition,marker:'MAP_SURVEY_TUNING',cohort:'tuning_v29'});
 const h=fields(lines.find(l=>l.includes('MAP_SURVEY_TUNING '))),start=+h.t,end=start+base.duration_s;
 const escape={move_samples:0,blocked_samples:0,release_samples:0,probe_us:[]},clearance={probes:0,fits:{},probe_us:[]};
 let awareSamples=0;
 for(const line of lines){const e=fields(line);if(!Number.isFinite(+e.t)||+e.t<start||+e.t>end+0.1)continue;
  if(line.includes('BOT_FRAG_ESCAPE ')){if(Object.hasOwn(escape,e.action+'_samples'))escape[e.action+'_samples']++;if(e.action!=='release'&&Number.isFinite(+e.probe_us))escape.probe_us.push(+e.probe_us);}
  if(line.includes('BOT_CLEARANCE_PROBE ')){clearance.probes++;clearance.fits[e.fit]=(clearance.fits[e.fit]||0)+1;if(Number.isFinite(+e.probe_us))clearance.probe_us.push(+e.probe_us);}
  if(line.includes('BT_FRAG_AWARE_SAMPLE '))awareSamples++;
 }
 const timing=a=>{a.sort((a,b)=>a-b);return {n:a.length,p95_us:a.length?a[Math.ceil(a.length*0.95)-1]:null,max_us:a.length?a[a.length-1]:null};};
 return {...base,tuning:{awareness_samples:awareSamples,escape:{...escape,probe_us:timing(escape.probe_us)},clearance:{...clearance,probe_us:timing(clearance.probe_us)}},
  limits:base.limits+' Probe timings cover only the local controller call/hull checks, not overall server-frame p95. Move samples are commands, not independently verified escapes. Generic corner classification remains conservative; actual clearance probe/intent events establish execution. Native and Squirrel handle namespaces are not joined by assumption.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
 const raw=fs.readFileSync(get('--log')),r=reviewTuningRound(raw.toString('utf8').split(/\r?\n/));r.log_sha256=crypto.createHash('sha256').update(raw).digest('hex');
 fs.writeFileSync(get('--out'),JSON.stringify(r,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({map:r.map,cell:r.cell,low:r.low_progress_percent,tuning:r.tuning,errors:r.error_markers}));
}
