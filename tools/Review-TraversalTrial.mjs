import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {reviewRouteContinuity} from './Review-RouteContinuity.mjs';
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
export function reviewTraversalTrial(lines){
  const replay=reviewRouteContinuity(lines),maps=new Map(),epochs=new Map(),pending=new Map();
  const get=map=>{if(!maps.has(map))maps.set(map,{map,begins:0,completed:0,failed:0,cancelled:0,unmatched_ends:0,censored:0,failure_reasons:{},cancel_reasons:{},state_samples:{},completed_duration_s:[]});return maps.get(map);};
  for(const line of lines){
    if(line.includes('BOT_FRAME ')){const e=fields(line);epochs.set(e.epoch,e.map);}
    const match=line.match(/\b(BOT_TRAVERSAL|BOT_TRAVERSAL_STATE)\s/);if(!match)continue;
    const e=fields(line),map=epochs.get(e.epoch)||'unknown',m=get(map),key=e.epoch+'|'+e.slot;
    if(match[1]==='BOT_TRAVERSAL_STATE'){m.state_samples[e.phase]=(m.state_samples[e.phase]||0)+1;continue;}
    if(e.event==='begin'){
      if(pending.has(key))get(pending.get(key).map).censored++;
      pending.set(key,{map,t:+e.t});m.begins++;continue;
    }
    const begin=pending.get(key);
    if(!begin){m.unmatched_ends++;continue;}
    pending.delete(key);
    if(e.event==='complete'){m.completed++;m.completed_duration_s.push(+e.t-begin.t);}
    else if(e.event==='failed'){m.failed++;m.failure_reasons[e.reason]=(m.failure_reasons[e.reason]||0)+1;}
    else if(e.event==='cancel'){m.cancelled++;m.cancel_reasons[e.reason]=(m.cancel_reasons[e.reason]||0)+1;}
  }
  for(const begin of pending.values())get(begin.map).censored++;
  return {schema_version:1,replay,maps:[...maps.values()],limits:'Default-off native prototype. Logged completion requires its ground/XY/height predicate, not independent video confirmation. Different maps/phases/links are not controlled traversal success comparisons. Cancellations and censored actions remain separate from failed/successful attempts. No human difficulty, speed/physics improvement or full-map validation claim.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
  for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  const raw=fs.readFileSync(get('--log')),r=reviewTraversalTrial(raw.toString('utf8').split(/\r?\n/));
  r.log_sha256=crypto.createHash('sha256').update(raw).digest('hex');
  fs.writeFileSync(get('--out'),JSON.stringify(r,null,2)+'\n');
  console.log(JSON.stringify(r.maps,null,2));
}
