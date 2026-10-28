import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewCornerRound} from '../tools/Review-CornerRound.mjs';
const begin=['MAP_SURVEY_BEGIN map=mp_test goal=50','MAP_SURVEY_CORNER_GUARD value=1 safety=false retarget=false'];
const end='MAP_SURVEY_RESULT map=mp_test valid=true elapsed=30 imc=50 militia=40';
test('only the completed survey window contributes movement and explicit guard evidence',()=>{
  const lines=['BOT_CORNER_GUARD event=begin',...begin];
  for(let t=0;t<=12;t++){
    lines.push(`BOT_PLAYER epoch=1 t=${t} slot=2 id=9 bot=1 alive=1 titan=0 x=0 y=0 z=0`);
    lines.push(`BOT_TRACE epoch=1 t=${t} slot=2 state=pursue jumps=0 commands=${t*30} yaw_travel=0`);
  }
  lines.push('BOT_CORNER_GUARD event=begin','BOT_CORNER_GUARD event=end reason=advance held_s=1',end,'BOT_CORNER_GUARD event=begin');
  const r=reviewCornerRound(lines);assert.equal(r.live_pilot_samples,13);assert.equal(r.low_progress_samples,3);
  assert.equal(r.navigation.corner_guard.begins,1);assert.equal(r.navigation.corner_guard.ends.advance,1);
});
test('partial, missing-variant and unrelated-switch rounds cannot enter comparisons',()=>{
  for(const lines of [begin,[begin[0],end],[begin[0],'MAP_SURVEY_CORNER_GUARD value=1 safety=true retarget=false',end]])assert.throws(()=>reviewCornerRound(lines));
});
test('no pilot samples is missing information rather than zero stall rate',()=>{
  const r=reviewCornerRound([...begin,end]);assert.equal(r.live_pilot_samples,0);assert.equal(r.low_progress_percent,null);
});
