import test from 'node:test';
import assert from 'node:assert/strict';
import {parseDiag, analyzeDiag} from '../tools/Analyze-NavDiagnostics.mjs';
// Guard ends are explicit outcomes; disappearance/death is not inferred success.
test('corner guard records remain distinct from route corners and exclude invalid durations',()=>{
  const lines=['BOT_CORNER_GUARD epoch=1 t=1 slot=2 event=begin',
    'BOT_CORNER_HOLD epoch=1 t=2 slot=2 dz=90',
    'BOT_CORNER_GUARD epoch=1 t=3 slot=2 event=end reason=advance held_s=2',
    'BOT_CORNER_GUARD epoch=1 t=4 slot=2 event=end reason=replan held_s=NaN'];
  const out=analyzeDiag(lines.map(parseDiag));
  assert.equal(out.corners.total,0);assert.equal(out.corner_guard.begins,1);
  assert.equal(out.corner_guard.hold_samples,1);assert.equal(out.corner_guard.ends.advance,1);
  assert.equal(out.corner_guard.ends.replan,1);assert.equal(out.corner_guard.duration_samples,1);
  assert.equal(out.corner_guard.completed_duration_s,2);
});

const stall = (slot, t, x, extra = {}) => `[info] BOT_STALL epoch=1 t=${t} slot=${slot} reason=no_progress state=pursue visible=0 grounded=1 speed=3 corner_flags=0 corner_jump=0 next_dist=380 next_dz=22.0 partial=0 fit=Blocked duck_state=0 x=${x} y=-300.0 z=74.0`
  .replace(/(\w+)=([^\s]+)/g, (m, k, v) => k in extra ? `${k}=${extra[k]}` : m);

test('parser keeps structured fields only and handles bracketed values', () => {
  assert.equal(parseDiag('auth token=secret'), null);
  const e = parseDiag('[info] BOT_VIEWCHECK epoch=1 slot=3 eye_angles=[1.0, 90.0, 0.0] view_angles_raw=[0.1, 0.9, 0.0] eye_height=60.0 stand=([-16.0, -16.0, 0.0], [16.0, 16.0, 72.0]) duck=([-16.0, -16.0, 0.0], [16.0, 16.0, 47.0]) plausible=1 duck_state=0');
  assert.equal(e.type, 'BOT_VIEWCHECK'); assert.equal(e.eye_angles, '[1.0, 90.0, 0.0]'); assert.equal(e.plausible, '1');
  assert.match(e.stand, /72\.0/);
});

test('overlapping stall samples collapse into incidents per slot', () => {
  const lines = [stall(3, 10, 4120), stall(3, 13, 4121), stall(3, 16, 4119), stall(4, 16, 4120), stall(3, 40, 4120), stall(3, 41, 1000)];
  const r = analyzeDiag(lines.map(parseDiag));
  assert.equal(r.stalls.samples, 6);
  assert.equal(r.stalls.incidents, 4);
});

test('decision rule favours link handling when most incidents sit at link corners or partial routes', () => {
  const lines = [stall(1, 1, 0, {corner_jump: '16'}), stall(2, 1, 0, {partial: '1'}), stall(3, 1, 0, {corner_flags: '4'}), stall(4, 1, 0, {fit: 'DuckOnly'})];
  const r = analyzeDiag(lines.map(parseDiag));
  assert.equal(r.decision.link_or_partial_share, 0.75);
  assert.equal(r.decision.recommendation, 'prioritise link/partial-route handling');
  const crouch = analyzeDiag([stall(1, 1, 0, {fit: 'DuckOnly'}), stall(2, 1, 0, {fit: 'DuckOnly'}), stall(3, 1, 0)].map(parseDiag));
  assert.equal(crouch.decision.recommendation, 'crouch recovery justified');
  assert.equal(analyzeDiag([]).decision.recommendation, 'insufficient stall incidents');
});

test('jump type 255 and zero are not links; new epochs reset incident grouping', () => {
  const lines = [stall(1, 10, 0, {corner_jump: '255'}), '[info] BOT_STALL epoch=2 t=1 slot=1 reason=no_progress state=engage visible=1 grounded=1 speed=0 corner_flags=0 corner_jump=0 next_dist=50 next_dz=0 partial=0 fit=StandClear duck_state=0 x=0 y=-300 z=74'];
  const r = analyzeDiag(lines.map(parseDiag));
  assert.equal(r.stalls.incidents, 2); assert.equal(r.stalls.link_or_partial, 0);
});

test('paths, corners, stuck and crouch summaries count what was logged', () => {
  const r = analyzeDiag([
    '[info] BOT_PATH epoch=1 t=1 slot=2 ok=1 status=0x40000040 partial=1 points=4 links=1 corners=1:0,0:16 end_gap=420 sx=0 sy=0 sz=0 gx=1 gy=1 gz=1 target=7 suppressed=12',
    '[info] BOT_CORNER epoch=1 t=1 slot=2 flags=0 jump=16 remaining=3 x=1 y=1 z=1 dz=22 dist=380',
    '[info] BOT_STUCK epoch=1 map=mp_eden t=5 slot=2 state=engage visible=1 titan=0 age=1.5 episodes=1 duck_state=0 x=1 y=1 z=1',
    '[info] BOT_CROUCH epoch=1 t=6 slot=2 intent=Crouch fit=Some(DuckOnly) duck=1 duck_state=1 attempts=1 successes=0 failures=0 x=1 y=1 z=1',
    '[info] BOT_CROUCH epoch=1 t=7 slot=2 intent=Normal fit=None duck=0 duck_state=0 attempts=1 successes=1 failures=0 x=1 y=1 z=1',
  ].map(parseDiag));
  assert.equal(r.paths.partial, 1); assert.equal(r.paths.suppressed, 12);
  assert.equal(r.corners.links, 1); assert.equal(r.stuck.by_state.engage, 1);
  assert.equal(r.crouch.tests, 1); assert.equal(r.crouch.successes_max, 1);
});
