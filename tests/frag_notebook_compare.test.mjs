import test from 'node:test';
import assert from 'node:assert/strict';
import {compareFragNotebook} from '../tools/Compare-FragNotebook.mjs';

const ctx = map => 'WNOTE_CONTEXT schema=1 map=' + map;
const probe = (t, attacker='41', victim='42', relation='enemy', map='mp_eden') =>
  'BT_FRAG_DAMAGE schema=1 map=' + map + ' t=' + t + ' attacker=' + attacker
    + ' victim=' + victim + ' inflictor=801 relation=' + relation + ' damage=55 secret=abc';
const hit = (event, t, attacker='41', victim='42', life='0', extra='') =>
  'WNOTE_HIT event=' + event + ' t=' + t + ' attacker=' + attacker + ' victim=' + victim
    + ' life=' + life + ' akind=bot vkind=human atitan=false force=false'
    + ' ateam=2 vteam=3 gun=mp_weapon_frag_grenade hp=100 ' + extra;
const post = (event, life='0', hp='0', victim='42') =>
  'WNOTE_POST event=' + event + ' t=12.03 victim=' + victim + ' life=' + life + ' hp_after=' + hp;
const death = (event, life='0', victim='42') =>
  'WNOTE_DEATH event=' + event + ' t=12.03 victim=' + victim + ' life=' + life;

test('one-to-one same-context frag callback agrees with independent health and death records', () => {
  const r = compareFragNotebook([ctx('mp_eden'),probe(12),hit(7,12.01),post(7),death(7)].join('\n'));
  assert.equal(r.uniquely_matched,1);
  assert.equal(r.post_health_decrease_consistent,1);
  assert.equal(r.fatal_notebook_record_consistent,1);
  assert.equal(r.missing_clean_post,0);
  assert.equal(r.maps[0].map,'mp_eden');
  assert.ok(!JSON.stringify(r).includes('secret=abc'));
  assert.ok(!JSON.stringify(r).includes('attacker=41'));
  assert.ok(r.limits.some(x=>x.includes('not proof a grenade caused')));
});
test('ambiguous rapid notebook callbacks cannot be automatically counted', () => {
  const r=compareFragNotebook([ctx('mp_eden'),probe(12),hit(7,12.01),hit(8,12.02),post(7),death(7)].join('\n'));
  assert.equal(r.ambiguous,1);
  assert.equal(r.uniquely_matched,0);
  assert.equal(r.fatal_notebook_record_consistent,0);
});
test('two probe callbacks competing for one notebook hit are both ambiguous', () => {
  const r=compareFragNotebook([ctx('mp_eden'),probe(12),probe(12.02),hit(7,12.01)].join('\n'));
  assert.equal(r.ambiguous,2);
  assert.equal(r.uniquely_matched,0);
});
test('map or recorder context changes cannot cross-match an unrelated callback', () => {
  const r=compareFragNotebook([probe(12),ctx('mp_meadow'),probe(12),hit(7,12.01),
    ctx('mp_eden'),hit(8,12.01)].join('\n'));
  assert.equal(r.probe_callbacks_total,2);
  assert.equal(r.unscoped_or_invalid_probe_callbacks,2);
  assert.equal(r.uniquely_matched,0);
  assert.equal(r.status,'context_or_invalid_callbacks_review_required');
});
test('signed encoded handles can be matched but never leak', () => {
  const a='-2147483000',v='-2147482000';
  const r=compareFragNotebook([ctx('mp_eden'),probe(12,a,v),hit(7,12.01,a,v)].join('\n'));
  assert.equal(r.uniquely_matched,1);
  assert.ok(!JSON.stringify(r).includes(a));
  assert.ok(!JSON.stringify(r).includes(v));
});
test('gap or mismatched life invalidates post-death concordance', () => {
  const a=compareFragNotebook([ctx('mp_eden'),probe(12),hit(7,12.01),
    post(7),death(7),'WNOTE_GAP event=7 victim=42 life=0'].join('\n'));
  assert.equal(a.uniquely_matched,1);
  assert.equal(a.missing_clean_post,1);
  assert.equal(a.fatal_notebook_record_consistent,0);
  const b=compareFragNotebook([ctx('mp_eden'),probe(12),hit(7,12.01),
    post(7,'1'),death(7)].join('\n'));
  assert.equal(b.missing_clean_post,1);
  assert.equal(b.post_health_decrease_consistent,0);
});
test('do not equate a weapon or human damage note to a bot frag callback', () => {
  const r=compareFragNotebook([ctx('mp_eden'),probe(12),hit(7,12.01).replace(
    'gun=mp_weapon_frag_grenade','gun=mp_weapon_r97'),hit(8,12.01).replace('akind=bot','akind=human'),
    hit(9,12.4)].join('\n'));
  assert.equal(r.uniquely_matched,0);
  assert.equal(r.unmatched,1);
});
test('probe errors and empty input never imply that zero frags occurred', () => {
  const r=compareFragNotebook('[warn] BT_FRAG_DAMAGE_ERROR schema=1\n');
  assert.equal(r.probe_errors_logged,1);
  assert.equal(r.status,'probe_error_incomplete');
  const empty=compareFragNotebook('no events');
  assert.equal(empty.status,'no_unique_matches_cannot_infer_no_damage');
  assert.equal(empty.maps.length,0);
});

test('missing notebook force/Titan flags or invalid teams are never treated as matches', () => {
  const base=[ctx('mp_eden'),probe(12)];
  const variants=[
    hit(7,12.01).replace('force=false',''),
    hit(7,12.01).replace('atitan=false','atitan=true'),
    hit(7,12.01).replace('ateam=2','ateam=0'),
    hit(7,12.01).replace('force=false','force=true'),
  ];
  for(const row of variants){
    const r=compareFragNotebook([...base,row].join('\n'));
    assert.equal(r.uniquely_matched,0);
    assert.equal(r.unmatched,1);
  }
});
