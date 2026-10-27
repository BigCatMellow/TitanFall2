import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
test('live tail joins partial records, ignores unrelated lines and finalizes after owned process exits',{timeout:20000},async()=>{
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'weapon-recorder-test-'));
  const profile=path.join(temp,'profile'),out=path.join(temp,'notes');fs.mkdirSync(path.join(profile,'logs'),{recursive:true});
  const owner=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});
  let collector;
  try{
    const log=path.join(profile,'logs','nslog-fixture.txt');fs.writeFileSync(log,'unrelated private data must not be copied\n');
    collector=spawn(process.execPath,['--preserve-symlinks','--preserve-symlinks-main',path.join(root,'tools/Record-WeaponNotes.mjs'),'--profile',profile,'--out',out,'--pid',String(owner.pid),'--since',String(Date.now()-2000)],{stdio:'ignore'});
    const exited=new Promise(resolve=>collector.once('exit',resolve));
    fs.appendFileSync(log,'[info] WNOTE_CONTEXT schema=1 map=mp_eden mode=normal_');
    await sleep(1300);
    fs.appendFileSync(log,'play config=on tick=0.016667\nstack print("WNOTE_DEATH t=0")\n[info] WNOTE_LIFE t=1 victim=20 life=1 kind=bot\n');
    await sleep(1300);owner.kill();
    assert.equal(await exited,0);
    const events=fs.readFileSync(path.join(out,'events.jsonl'),'utf8').trim().split('\n').map(JSON.parse);
    assert.equal(events.length,2);assert.equal(events[0].mode,'normal_play');
    assert.equal(JSON.parse(fs.readFileSync(path.join(out,'summary.json'))).state,'complete');
    assert.doesNotMatch(fs.readFileSync(path.join(out,'events.jsonl'),'utf8'),/private data|stack print/);
  }finally{
    owner.kill();if(collector&&collector.exitCode===null)collector.kill();
    assert.equal(path.dirname(path.resolve(temp)),path.resolve(os.tmpdir()));
    assert.ok(path.basename(temp).startsWith('weapon-recorder-test-'));
    fs.rmSync(temp,{recursive:true,force:true});
  }
});
