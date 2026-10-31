// Replay isolated health / lifecycle evidence; never exports raw actors or paths.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const expected={bot_self_quarter:90,bot_self_disabled:60,bot_self_full:60,bot_self_immune:100,bot_self_invalid_negative:60,bot_self_invalid_high:60,human_self:60,bot_to_enemy:60,bot_to_human:60,human_to_bot:60,bot_to_ally:100,bot_self_bullet:60,bot_self_arc:60};
export function reviewFragSelf(log){
 const errorLines=log.split(/\r?\n/).filter(l=>/SCRIPT ERROR|COMPILE ERROR|FatalError|Host_Error|Access violation|panicked|FRAG_SELF_TEST_FAILED|WNOTE_ERROR|WNOTE_FIRE_ERROR|BOT_ROSTER_ERROR/.test(l));
 if(errorLines.length)throw Error('Runtime errors in evidence');
 const matrices=[];const combat=[];let current=null,activeCombat=null;let natural=0;
 for(const line of log.split(/\r?\n/)){
  let m=line.match(/FRAG_SELF_TEST_PHASE name=(\S+) map=(\S+)/);
  if(m){if(current)throw Error('Unfinished matrix');current={phase:m[1],map:m[2],seen:new Set()};}
  m=line.match(/FRAG_SELF_TEST_CASE map=(\S+) name=(\S+) expected=(\d+) hp=(\d+)/);
  if(m){if(!current||m[1]!==current.map||!(m[2] in expected)||current.seen.has(m[2])||+m[3]!==expected[m[2]]||+m[4]!==expected[m[2]])throw Error('Invalid health-delta case');current.seen.add(m[2]);}
  m=line.match(/FRAG_SELF_TEST_MATRIX_PASS name=(\S+)/);
  if(m){if(!current||m[1]!==current.phase||current.seen.size!==13)throw Error('Incomplete matrix');matrices.push({map:current.map,phase:current.phase,cases:current.seen.size});current=null;}
  m=line.match(/FRAG_SELF_TEST_COMBAT_START map=(\S+)/);if(m){if(activeCombat)throw Error('Overlapping combat');activeCombat={map:m[1],scaled_hits:0};}
  m=line.match(/BT_FRAG_SELF_SCALE schema=1 map=(\S+) t=\S+ before=(\S+) after=(\S+) scale=(\S+)/);
  if(m&&activeCombat){const [before,after,scale]=m.slice(2).map(Number);if(m[1]!==activeCombat.map||!Number.isFinite(before)||before<=0||scale!==0.25||Math.abs(after-before*0.25)>0.001)throw Error('Natural damage scaling mismatch');activeCombat.scaled_hits++;natural++;}
  m=line.match(/FRAG_SELF_TEST_COMBAT_PASS map=(\S+)/);if(m){if(!activeCombat||m[1]!==activeCombat.map)throw Error('Missing combat start');combat.push(activeCombat);activeCombat=null;}
 }
 if(current||activeCombat||matrices.map(m=>m.map+':'+m.phase).join(',')!=='mp_drydock:initial,mp_drydock:respawn,mp_glitch:initial,mp_glitch:respawn'||combat.map(m=>m.map).join(',')!=='mp_drydock,mp_glitch'||combat.some(m=>m.scaled_hits<1)||!log.includes('FRAG_SELF_TEST_LOBBY')||!log.includes('FRAG_SELF_TEST_DONE'))throw Error('Incomplete lifecycle or real-frag execution');
 return {schema_version:1,cases:52,matrices,combat,natural_scaled_hits:natural,runtime_errors:0,limits:'Synthetic health deltas and short real combat execution, not efficacy, scoreboard, human balance, or immunity to enemy grenades. No actor identifiers exported.'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const run=process.argv[2];if(!run)throw Error('Supply private validation directory');
 const bytes=fs.readFileSync(path.join(run,'raw-session.log'));const result=reviewFragSelf(bytes.toString('utf8'));
 const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
 result.raw_sha256=crypto.createHash('sha256').update(bytes).digest('hex').toUpperCase();
 result.script_sha256=hash(path.join(repo,'BT7274.FragSelfDamage/mod/scripts/vscripts/bt7274_frag_self_damage.nut'));
 result.manifest_sha256=hash(path.join(repo,'BT7274.FragSelfDamage/mod.json'));
 fs.writeFileSync(path.join(run,'evidence.json'),JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
}
