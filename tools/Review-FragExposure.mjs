// Read-only projectile exposure review. Never export actor/projectile handles.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {reviewRouteStudy} from './Review-RouteStudy.mjs';
const fields=s=>Object.fromEntries([...s.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
const median=values=>{const a=values.filter(Number.isFinite).sort((a,b)=>a-b);return a.length?(a[Math.floor((a.length-1)/2)]+a[Math.ceil((a.length-1)/2)])/2:null;};
export function reviewFragExposure(lines){
  const base=reviewRouteStudy(lines);
  if(base.error_markers)throw Error('Runtime errors exclude this cohort');
  const header=fields(lines.find(l=>l.includes('MAP_SURVEY_ROUTE ')));
  const start=+header.t,end=start+base.duration_s,observed=new Map(),events=[];
  for(const line of lines){
    const m=line.match(/\b(BFRAG_SPAWN|BFRAG_SAMPLE|BFRAG_KILL)\s/);if(!m)continue;
    const e=fields(line);if(+e.t<start||+e.t>end+0.1)continue;
    if(m[1]==='BFRAG_SPAWN'){
      if(observed.has(e.projectile))throw Error('Duplicate projectile spawn within cohort');
      observed.set(e.projectile,{spawn:e,samples:[],kills:[]});
    }else events.push({...e,type:m[1]});
  }
  let unmatched=0;
  for(const e of events){const p=observed.get(e.projectile);if(!p||+e.t<+p.spawn.t){if(e.type==='BFRAG_KILL')unmatched++;continue;}
    (e.type==='BFRAG_SAMPLE'?p.samples:p.kills).push(e);
  }
  const groups=new Map();
  for(const p of observed.values()){
    const speed=+p.spawn.speed,label=!Number.isFinite(speed)?'unknown':speed<=200?'0-200u_s':speed<=800?'(200,800]u_s':'>800u_s';
    if(!groups.has(label))groups.set(label,{first_observed_speed:label,observed_projectiles:0,projectiles_with_self_kill:0,projectiles_with_enemy_kill:0,projectiles_with_friendly_kill:0,self_kill_callbacks:0,enemy_kill_callbacks:0,initial_distances:[],self_ages:[],last_distances:[],sample_lags:[]});
    const g=groups.get(label);g.observed_projectiles++;g.initial_distances.push(+p.spawn.owner_dist);
    const self=p.kills.filter(k=>k.self==='true'),enemy=p.kills.filter(k=>k.self!=='true'&&k.friendly!=='true');
    g.projectiles_with_self_kill+=+(self.length>0);g.projectiles_with_enemy_kill+=+(enemy.length>0);
    g.projectiles_with_friendly_kill+=+p.kills.some(k=>k.friendly==='true');
    g.self_kill_callbacks+=self.length;g.enemy_kill_callbacks+=enemy.length;
    for(const k of self){
      g.self_ages.push(+k.t-(+p.spawn.t));
      const last=p.samples.filter(s=>+s.t<=+k.t&&+k.t-(+s.t)<=0.6).sort((a,b)=>+b.t-(+a.t))[0];
      if(last&&Number.isFinite(+last.owner_dist)){g.last_distances.push(+last.owner_dist);g.sample_lags.push(+k.t-(+last.t));}
    }
  }
  return {schema_version:1,map:base.map,variant:base.variant,observed_projectiles:observed.size,unmatched_kill_callbacks:unmatched,
    groups:[...groups.values()].map(g=>{const {initial_distances,self_ages,last_distances,sample_lags,...counts}=g;return {...counts,
      median_first_owner_distance:median(initial_distances),median_first_seen_to_self_kill_s:median(self_ages),
      self_kills_with_recent_sample:last_distances.length,median_last_owner_distance_before_self_kill:median(last_distances),median_sample_lag_s:median(sample_lags)};}),
    limits:'Observed valid-owner projectiles in one completed frozen bot-only round. Speed is first observed, up to sampler delay; it does not identify thrown, dropped, bounced or stuck grenades. Owner distance is sampled and may cross owner death/respawn. Latest samples are <=0.6s before self-kill, not positions at explosion. Outcome groups overlap and near-end/missed projectiles are censored. Association is not a causal safety diagnosis; no handles exported.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  const raw=fs.readFileSync(get('--log')),r=reviewFragExposure(raw.toString('utf8').split(/\r?\n/));r.log_sha256=crypto.createHash('sha256').update(raw).digest('hex');
  fs.writeFileSync(get('--out'),JSON.stringify(r,null,2)+'\n');console.log(JSON.stringify(r));
}
