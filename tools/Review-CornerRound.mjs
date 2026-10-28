// Read-only survey-window metrics. Raw actor/account data never exported.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parseDiag,analyzeDiag} from './Analyze-NavDiagnostics.mjs';
import {markLowProgress} from './Analyze-PlayedWeaponSession.mjs';
const fields=line=>Object.fromEntries([...line.matchAll(/(?:^|\s)([a-z_]+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
export function reviewCornerRound(lines){
  let active=false,begins=0,result=null,variant=null,header=null,errors=0;
  const players=new Map(),traces=new Map(),diagnostics=[];
  const key=e=>`${e.epoch}|${e.t}|${e.slot}`;
  for(const line of lines){
    if(/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|BOT_ROSTER_ERROR|WNOTE_ERROR/.test(line))errors++;
    if(line.includes('MAP_SURVEY_BEGIN ')){active=true;begins++;header=fields(line);continue;}
    if(line.includes('MAP_SURVEY_RESULT ')){result=fields(line);active=false;continue;}
    if(!active)continue;
    if(line.includes('MAP_SURVEY_CORNER_GUARD '))variant=fields(line);
    const d=parseDiag(line);if(d)diagnostics.push(d);
    const m=line.match(/(?:^|\s|\])(BOT_PLAYER|BOT_TRACE)\s/);if(!m)continue;
    const e=fields(line);if(m[1]==='BOT_PLAYER')players.set(key(e),e);else traces.set(key(e),e);
  }
  if(begins!==1||!result||result.valid!=='true')throw Error('Require exactly one completed valid survey round');
  if(!variant||!['0','1'].includes(variant.value)||variant.safety!=='false'||variant.retarget!=='false')throw Error('Missing or invalid isolated navigation variant');
  const rows=[...players.values()].filter(p=>p.bot==='1').map(p=>({...p,...traces.get(key(p))}));
  markLowProgress(rows);
  const pilots=rows.filter(p=>p.alive==='1'&&p.titan==='0'&&p.state);
  const low=pilots.filter(p=>p.low);
  return {schema_version:1,map:result.map,goal:Number.isFinite(+header.goal)?+header.goal:null,corner_guard:+variant.value,duration_s:+result.elapsed,error_markers:errors,
    score:{imc:+result.imc,militia:+result.militia},live_pilot_samples:pilots.length,low_progress_samples:low.length,
    low_progress_percent:pilots.length?100*low.length/pilots.length:null,navigation:analyzeDiag(diagnostics),
    limits:'One bot-only survey window; requested goal is recorded separately. Low progress uses overlapping live-pilot navigation/recovery/boarding samples over10–13s with <50XY displacement; short unsampled deaths can be missed. Counts are not independent incidents, visual observation or causal improvement. Guard advances/replans are native recorded outcomes; missing ends on life/early returns remain censored. Different maps, scores and durations stay separate; no aim/damage/balance conclusion.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];
  for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  const bytes=fs.readFileSync(get('--log')),r=reviewCornerRound(bytes.toString('utf8').split(/\r?\n/));
  r.log_sha256=crypto.createHash('sha256').update(bytes).digest('hex');
  fs.writeFileSync(get('--out'),JSON.stringify(r,null,2)+'\n');
  console.log(JSON.stringify({map:r.map,guard:r.corner_guard,samples:r.live_pilot_samples,low_percent:r.low_progress_percent,errors:r.error_markers}));
}
