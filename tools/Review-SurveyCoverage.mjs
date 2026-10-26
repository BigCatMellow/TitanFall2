// Reads private completed trials; publishes derived bot-only metrics, never raw saves/logs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import zlib from 'node:zlib';
import assert from 'node:assert/strict';
const args=process.argv.slice(2), value=k=>args[args.indexOf(k)+1];
const nav=new Set(['pursue','recover','embark','retreat']);
const pct=(n,d)=>d?Math.round(10000*n/d)/100:null;
function mark(rows){
  const groups=new Map();
  for(const r of rows){r.low=false;if(r.bot==='1'){if(!groups.has(r.slot))groups.set(r.slot,[]);groups.get(r.slot).push(r);}}
  for(const group of groups.values()){
    group.sort((a,b)=>+a.t-+b.t);
    for(let i=1;i<group.length;i++){
      const r=group[i];if(r.alive!=='1'||r.titan!=='0'||!nav.has(r.state))continue;
      let continuous=true;
      for(let j=i-1;j>=0;j--){
        const p=group[j];
        if(p.alive!=='1'||p.titan!=='0'||p.id!==r.id||+group[j+1].t-(+p.t)>2.1)break;
        if(!nav.has(p.state))continuous=false;
        const age=+r.t-(+p.t);
        if(age>=10){r.low=age<=13&&continuous&&Math.hypot(+r.x-(+p.x),+r.y-(+p.y))<50;break;}
      }
    }
  }
}
if(args.includes('--self-test')){
  const fixture=()=>Array.from({length:7},(_,i)=>({bot:'1',slot:'1',id:'5',alive:'1',titan:'0',state:'pursue',t:String(i*2),x:'0',y:'0'}));
  let a=fixture();mark(a);assert.equal(a.filter(r=>r.low).length,2);
  a=fixture();a[2].state='engage';mark(a);assert.equal(a.filter(r=>r.low).length,0);
  a=fixture();a[2].alive='0';mark(a);assert.equal(a.filter(r=>r.low).length,0);
  a=fixture();a[3].t='5';mark(a);assert.equal(a.filter(r=>r.low).length,0);
  console.log('PASS: continuous navigation, combat interruption, life boundary and sampling gap fixtures');
  process.exit(0);
}
if(!args.includes('--batch')||!args.includes('--out'))throw new Error('Use --batch PRIVATE_SUPERVISOR --out REPORT_DIRECTORY');
const batch=value('--batch'),out=value('--out');
const json=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const status=json(path.join(batch,'status.json'));
const trials=[...status.prior_completed,...status.results.filter(r=>r.status==='passed')];
function csv(text){
  const records=[],row=[];let v='',quoted=false;
  for(let i=0;i<text.length;i++){
    const c=text[i];
    if(c==='"'){if(quoted&&text[i+1]==='"'){v+='"';i++;}else quoted=!quoted;}
    else if(!quoted&&(c===','||c==='\r'||c==='\n')){row.push(v);v='';if(c!==','){records.push([...row]);row.length=0;if(c==='\r'&&text[i+1]==='\n')i++;}}
    else v+=c;
  }
  if(v||row.length){row.push(v);records.push([...row]);}
  assert.equal(quoted,false);const header=records.shift();
  return records.filter(r=>r.length>1).map(r=>{assert.equal(r.length,header.length);return Object.fromEntries(header.map((k,i)=>[k,r[i]]));});
}
const fields=line=>Object.fromEntries([...line.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
const results=[],archives=new Map();
for(const trial of trials){
  const rawPath=path.join(trial.directory,'raw-session.log'),bytes=fs.readFileSync(rawPath);
  let last=null,start=null,end=null,begin=null,core=null,errors=0;
  const evidence=[];
  for(const line of bytes.toString('utf8').split(/\r?\n/)){
    if(args.includes('--archive-evidence')){
      if(line.includes('NorthstarLauncher version:'))evidence.push('NorthstarLauncher version: '+line.split('version:')[1].trim());
      if(line.includes('local build:'))evidence.push(line.slice(line.indexOf('local build:')));
      const diagnostic=line.match(/\b(BOT_FRAME|BOT_PLAYER|BOT_TRACE|BOT_DECISION|BOT_COMBAT|BOT_WEAPON|BOT_ACTION|BOT_READY|BOT_TARGET_STATE|MAP_SURVEY_BEGIN|MAP_SURVEY_SCORE|MAP_SURVEY_RESULT|MAP_SURVEY_DONE|MAP_SURVEY_OBSERVER|MAP_SURVEY_KILL)\b/);
      if(diagnostic)evidence.push(line.slice(diagnostic.index));
    }
    if(line.includes('NorthstarLauncher version:'))core=line.split('version:')[1].trim();
    if(line.includes('BOT_FRAME ')){const f=fields(line);last={t:+f.t,map:f.map,epoch:f.epoch};}
    if(line.includes('MAP_SURVEY_BEGIN ')){begin=fields(line);assert.equal(last?.map,trial.map);start=last.t;}
    if(line.includes('MAP_SURVEY_RESULT ')){assert.equal(last?.map,trial.map);end=last.t;}
    if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|\[error\]/.test(line))errors++;
  }
  assert.equal(core,'1.31.14.0');assert.ok(start!==null&&end!==null&&end>=start);
  assert.equal(begin.bots,'16');assert.equal(begin.imc,'8');assert.equal(begin.militia,'8');assert.equal(begin.observer_alive,'0');
  assert.equal(+begin.goal,+trial.goal);assert.equal(+begin.engine_goal,+trial.goal);
  const rows=csv(fs.readFileSync(path.join(trial.directory,'movement','observations.csv'),'utf8').replace(/^\uFEFF/,''))
    .filter(r=>r.map===trial.map&&+r.t>=start&&+r.t<=end);
  mark(rows);
  const pilots=rows.filter(r=>r.bot==='1'&&r.alive==='1'&&r.titan==='0');
  const low=pilots.filter(r=>r.low);
  const engage=pilots.filter(r=>r.state==='engage'&&r.visible==='1'&&+r.target>=0);
  const cells=new Map();
  for(const r of low){const key=`${Math.round(+r.x/128)*128},${Math.round(+r.y/128)*128},${Math.round(+r.z/64)*64}`;if(!cells.has(key))cells.set(key,{cell:key,samples:0,slots:new Set()});const c=cells.get(key);c.samples++;c.slots.add(r.slot);}
  results.push({map:trial.map,goal:+trial.goal,observer_loadout_restore:trial.observer_loadout_restore??'not_recorded',
    imc:+trial.result.imc,militia:+trial.result.militia,elapsed:+trial.result.elapsed,finish:trial.result.reason,
    window_start:start,window_end:end,pilot_samples:pilots.length,continuous_navigation_low_samples:low.length,
    continuous_navigation_percent:pct(low.length,pilots.length),visible_engage_samples:engage.length,
    overhead_engage_samples:engage.filter(r=>+r.tz-(+r.z)>5000).length,
    errors_in_saved_log:errors,source_sha256:crypto.createHash('sha256').update(bytes).digest('hex'),
    hotspots:[...cells.values()].sort((a,b)=>b.samples-a.samples).slice(0,3).map(c=>({...c,slots:[...c.slots].sort((a,b)=>+a-+b)}))});
  if(evidence.length)archives.set(trial.map,evidence.join('\n')+'\n');
}
const limits='One bot-only round per map, with 200/75 goals and observer-restore configurations kept separate. Playing window uses preceding two-second telemetry frames at harness begin/result markers (approximate edges). Low progress is <50 XY units net displacement over10–13s, with the same sampled live pilot and continuous navigation/recovery/boarding states; gaps>2.1s break continuity. Samples overlap and are not independent incidents. Short unsampled deaths can be missed. High target selection is not firing/cast proof. No causal AI/balance or before/after improvement conclusion. No visual watching. Public output contains derived metrics and hashes only.';
fs.mkdirSync(out,{recursive:true});
if(archives.size){
  const archiveDir=path.join(out,'evidence');fs.mkdirSync(archiveDir,{recursive:true});
  const manifest=[];
  for(const [map,text]of archives){const bytes=zlib.gzipSync(Buffer.from(text));fs.writeFileSync(path.join(archiveDir,map+'.log.gz'),bytes);manifest.push({map,file:map+'.log.gz',lines:text.split('\n').length-1,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});}
  fs.writeFileSync(path.join(archiveDir,'manifest.json'),JSON.stringify({scope:'Exact whitelist of authored bot/survey diagnostics plus core/build headers; timestamps/auth/general logs/personal saved state omitted',files:manifest},null,2)+'\n');
}
fs.writeFileSync(path.join(out,'rounds.json'),JSON.stringify({snapshot:new Date().toISOString(),source_batch:path.basename(batch),state:status.state,completed:results.length,limits,rounds:results},null,2)+'\n');
const lines=['# Map survey review','',limits,'','| Map | Goal | Score IMC–Militia | Seconds | Live pilot samples | Sustained low progress |','|---|---:|---:|---:|---:|---:|',...results.map(r=>`| ${r.map} | ${r.goal} | ${r.imc}–${r.militia} | ${r.elapsed} | ${r.pilot_samples} | ${r.continuous_navigation_percent}% |`)];
fs.writeFileSync(path.join(out,'REVIEW.md'),lines.join('\n')+'\n');
console.log(JSON.stringify({completed:results.length,errors:results.reduce((n,r)=>n+r.errors_in_saved_log,0),top_low_progress:[...results].sort((a,b)=>b.continuous_navigation_percent-a.continuous_navigation_percent).slice(0,5).map(r=>({map:r.map,percent:r.continuous_navigation_percent,hotspots:r.hotspots}))}));
