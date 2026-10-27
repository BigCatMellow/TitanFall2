import fs from 'node:fs';
import path from 'node:path';
import {parseNote,writeNotes} from './weapon-notes.mjs';
const args=process.argv.slice(2),arg=k=>args[args.indexOf(k)+1];
for(const key of ['--profile','--pid','--since','--out'])if(!args.includes(key))throw new Error('Missing '+key);
const profile=arg('--profile'),pid=Number(arg('--pid')),since=Number(arg('--since')),out=arg('--out');
if(!Number.isInteger(pid)||pid<=0||!Number.isFinite(since))throw new Error('Invalid owned-session identifiers');
fs.mkdirSync(out,{recursive:true});
const events=[];let log=null,position=0,pending='',lastWrite=0,exitedAt=null;
const alive=()=>{try{process.kill(pid,0);return true;}catch{return false;}}; // Signal0 only checks existence; never stops the game.
const flush=state=>{writeNotes(out,events,{state,source_log:log?path.basename(log):null,updated:new Date().toISOString()});lastWrite=Date.now();};
try{
  while(true){
    if(!log){
      const folder=path.join(profile,'logs');
      if(fs.existsSync(folder)){
        const choices=fs.readdirSync(folder).filter(n=>/^nslog.*\.txt$/i.test(n)).map(n=>({file:path.join(folder,n),created:fs.statSync(path.join(folder,n)).birthtimeMs})).filter(r=>r.created>=since-2000).sort((a,b)=>b.created-a.created);
        log=choices[0]?.file??null;
      }
    }
    if(log){
      const size=fs.statSync(log).size;
      if(size<position)throw new Error('Source log truncated; do not merge unrelated streams');
      if(size>position){
        const fd=fs.openSync(log,'r');const buffer=Buffer.alloc(size-position);
        try{fs.readSync(fd,buffer,0,buffer.length,position);}finally{fs.closeSync(fd);}
        position=size;pending+=buffer.toString('utf8');const lines=pending.split(/\r?\n/);pending=lines.pop();
        const records=[];
        for(const line of lines){const event=parseNote(line);if(event){events.push(event);records.push(JSON.stringify(event));}}
        if(records.length)fs.appendFileSync(path.join(out,'events.jsonl'),records.join('\n')+'\n');
      }
    }
    if(Date.now()-lastWrite>=15000)flush('recording');
    if(!alive()){exitedAt??=Date.now();if(Date.now()-exitedAt>3000)break;}else exitedAt=null;
    if(!log&&Date.now()-since>180000)throw new Error('No new profile log within three minutes');
    await new Promise(resolve=>setTimeout(resolve,1000));
  }
  flush('complete');
}catch(error){flush('collector_error');fs.writeFileSync(path.join(out,'collector-error.txt'),String(error)+'\n');process.exitCode=1;}
