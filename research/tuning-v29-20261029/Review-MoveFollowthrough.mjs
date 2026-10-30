import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const fields=line=>Object.fromEntries([...line.matchAll(/(?:^|\s)(\w+)=([^\s]+)/g)].map(m=>[m[1],m[2]]));
export function reviewMoveFollowthrough(lines,{start=-Infinity,end=Infinity}={}){
  const positions=new Map(),moves=[];
  for(const line of lines){
    const player=line.includes('BOT_PLAYER '),move=line.includes('BOT_FRAG_ESCAPE ');
    if(!player&&!move)continue;
    const e=fields(line);if(e.epoch===undefined||e.slot===undefined||!Number.isFinite(+e.t))continue;
    if(+e.t<start-0.55||+e.t>end)continue;
    const key=e.epoch+':'+e.slot;
    if(player){const p={...e,t:+e.t};if(!positions.has(key))positions.set(key,[]);positions.get(key).push(p);}
    if(move&&e.action==='move'&&+e.t>=start)moves.push({key,t:+e.t});
  }
  for(const points of positions.values())points.sort((a,b)=>a.t-b.t);
  moves.sort((a,b)=>a.t-b.t);
  const selected=new Map(),distances=[];let windows=0,censored=0;
  const valid=p=>p&&p.bot==='1'&&p.alive==='1'&&p.titan==='0'&&p.id!==undefined&&['x','y','z'].every(k=>Number.isFinite(+p[k]));
  for(const move of moves){
    if(selected.has(move.key)&&move.t-selected.get(move.key)<1)continue;
    selected.set(move.key,move.t);windows++;
    const points=positions.get(move.key)||[];
    const before=points.findLast(p=>p.t<=move.t&&move.t-p.t<=0.55);
    const after=points.find(p=>p.t>=move.t+0.35&&p.t<=move.t+1);
    if(!valid(before)||!valid(after)||before.id!==after.id||points.some(p=>p.t>=before.t&&p.t<=after.t&&(!valid(p)||p.id!==before.id))){censored++;continue;}
    distances.push(Math.hypot(+after.x-before.x,+after.y-before.y,+after.z-before.z));
  }
  distances.sort((a,b)=>a-b);
  return {schema_version:1,move_commands:moves.length,spaced_command_windows:windows,usable_windows:distances.length,censored_windows:censored,
    windows_with_24_units_displacement:distances.filter(d=>d>=24).length,
    displacement:{median_units:distances.length?distances[Math.floor(distances.length/2)]:null,p95_units:distances.length?distances[Math.ceil(distances.length*0.95)-1]:null},
    limits:'Same native epoch/slot/entity and live pilot snapshots only. Commands are spaced at least1s per actor. Previous snapshot within0.55s; next snapshot0.35–1s after command. No observed intervening death/entity change. Unobserved transitions remain possible. Displacement may include ordinary movement and is not causal proof, grenade separation, safe escape, independent incidents or video. No Squirrel/native handle join or actor identifiers published.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  const args=process.argv.slice(2),get=k=>args[args.indexOf(k)+1];for(const k of ['--log','--out'])if(!args.includes(k))throw Error('Missing '+k);
  fs.writeFileSync(get('--out'),JSON.stringify(reviewMoveFollowthrough(fs.readFileSync(get('--log'),'utf8').split(/\r?\n/)),null,2)+'\n',{flag:'wx'});
}
