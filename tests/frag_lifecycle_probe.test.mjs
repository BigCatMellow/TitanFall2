import test from 'node:test';
import assert from 'node:assert/strict';
import {instrumentFragSource} from '../tools/Prepare-FragLifecycleProbe.mjs';
import {parseFragStage, analyzeFragLog} from '../tools/Analyze-FragLifecycle.mjs';

// Minimal signatures from public Northstar grenade code; no third-party game assets.
const fixture = [
  'untyped',
  'void function Grenade_OnWeaponTossPrep( entity weapon, WeaponTossPrepParams prepParams )',
  '{ weapon.w.startChargeTime = Time() }',
  'var function Grenade_OnWeaponTossReleaseAnimEvent( entity weapon, WeaponPrimaryAttackParams attackParams )',
  '{ var result = Grenade_OnWeaponToss_( weapon, attackParams, 1.0 ) }',
  'var function Grenade_OnWeaponTossCancelDrop( entity weapon, WeaponPrimaryAttackParams attackParams )',
  '{ var result = Grenade_OnWeaponToss_( weapon, attackParams, 0.2 ) }',
  'entity function Grenade_Launch()',
  '{ entity frag = weapon.FireWeaponGrenade( attackPos, throwVelocity, angularVelocity, fuseTime, damageFlags, damageFlags, isPredicted, isLagCompensated, true ) }',
  'void function HACK_CookGrenade()',
  '{ weapon.ForceReleaseFromServer() // Will eventually result in Grenade_OnWeaponToss_() or equivalent function',
  '}',
  'void function HACK_DropGrenadeOnDeath()',
  '{ entity grenade = Grenade_Launch( weapon, weaponOwner.GetOrigin(), velocity, PROJECTILE_NOT_PREDICTED, PROJECTILE_NOT_LAG_COMPENSATED ) }',
].join('\n');

test('insertion is selective and leaves original input unchanged', () => {
  const result = instrumentFragSource(fixture);
  assert.equal((result.match(/BT7274_FragLifecycleProbe\(/g) || []).length, 7);
  for (const stage of ['prep', 'spawn', 'spawn_null', 'release_callback',
    'cancel_drop_callback', 'forced_release_request', 'death_drop'])
    assert.ok(result.includes('"' + stage + '"'));
  assert.ok(result.includes('bot_frag_input_probe'));
  assert.ok(result.includes('#if SERVER'));
  assert.ok(!fixture.includes('BT7274_FragLifecycleProbe'));
});
test('unknown upstream signatures and previously instrumented source fail closed', () => {
  assert.throws(() => instrumentFragSource('void foo() {}'), /Expected an unmodified/);
  assert.throws(() => instrumentFragSource(fixture.replace('FireWeaponGrenade', 'OtherFunction')),
    /Unrecognized source signature/);
  assert.throws(() => instrumentFragSource(fixture + fixture), /Unrecognized source signature/);
  assert.throws(() => instrumentFragSource(instrumentFragSource(fixture)), /already instrumented/);
});

const line = (stage, fields = '') =>
  '[info] BT_FRAG_STAGE schema=1 map=mp_eden t=10 stage=' + stage
  + ' owner=41 weapon=409 projectile=800 cook_s=0.8 fuse_s=1.0 owner_gap=45 ' + fields;
test('parser rejects malformed or unsupported events', () => {
  assert.equal(parseFragStage('noise'), null);
  assert.equal(parseFragStage(line('explosion')), null);
  assert.equal(parseFragStage(line('spawn').replace('schema=1', 'schema=2')), null);
  assert.equal(parseFragStage(line('spawn').replace('owner=41', 'owner=secret')), null);
  assert.equal(parseFragStage(line('spawn').replace('t=10', 't=NaN')), null);
  const sample = parseFragStage(line('spawn'));
  assert.equal(sample.map, 'mp_eden');
  assert.equal(sample.projectile, 800);
});
test('server spawn return is counted, unlike callbacks or null returns', () => {
  const data = analyzeFragLog([
    line('prep'),
    line('spawn'),
    line('spawn'),
    line('release_callback'),
    line('spawn_null', 'x=private'),
    line('death_drop'),
  ].join('\n'));
  const m = data.maps[0];
  assert.equal(m.prep_events, 1);
  assert.equal(m.spawned_entities, 1);
  assert.equal(m.duplicate_projectile_spawn_events, 1);
  assert.equal(m.release_callbacks, 1);
  assert.equal(m.spawn_null_events, 1);
  assert.equal(m.death_drop_callbacks, 1);
  assert.equal(m.death_drops_with_logged_spawn, 1);
  assert.equal(m.spawn_with_owner_gap_under_120, 1);
  assert.ok(!JSON.stringify(data).includes('owner=41'));
  assert.ok(!JSON.stringify(data).includes('x=private'));
});
test('short fuse and close initial spawn are labeled inspection candidates', () => {
  const data = analyzeFragLog([
    line('spawn').replace('fuse_s=1.0', 'fuse_s=0.12'),
    line('spawn').replace('projectile=800', 'projectile=801')
      .replace('owner_gap=45', 'owner_gap=300'),
    line('spawn').replace('projectile=800', 'projectile=-1'),
    line('forced_release_request'),
  ].join('\n'));
  const m = data.maps[0];
  assert.equal(m.spawned_entities, 2);
  assert.equal(m.spawn_with_fuse_under_0_25s, 1);
  assert.equal(m.spawn_with_owner_gap_under_120, 1);
  assert.equal(m.invalid_spawn_handles, 1);
  assert.equal(m.forced_release_requests, 1);
  assert.ok(data.limits.some(x => x.includes('NOT danger thresholds')));
});
test('map groups are sanitized and never join BOT inputs to script entities', () => {
  const lines = [
    line('spawn'),
    line('cancel_drop_callback').replace('map=mp_eden', 'map=mp_meadow'),
    line('death_drop').replace('map=mp_eden', 'map=madeup'),
    'BOT_FRAG_INPUT epoch=1 slot=41 t=10 edge=press',
    'WNOTE_HIT attacker=41 gun=mp_weapon_frag_grenade',
  ].join('\n');
  const data = analyzeFragLog(lines);
  assert.deepEqual(data.maps.map(x => x.map), ['mp_eden', 'mp_meadow', 'unknown']);
  assert.equal(data.maps.reduce((s,x) => s + x.events_logged, 0), 3);
  assert.ok(data.limits.some(x => x.includes('identifier domains')));
});

test('recycled projectile handles after map or clock restart are independent events', () => {
  const data = analyzeFragLog([
    line('spawn').replace('t=10', 't=10'),
    line('spawn').replace('t=10', 't=10.1'), // duplicate in same segment
    line('spawn').replace('map=mp_eden', 'map=mp_meadow').replace('t=10', 't=1'),
    line('spawn').replace('map=mp_eden', 'map=mp_meadow').replace('t=10', 't=2'),
    line('spawn').replace('t=10', 't=0.1'), // return to same map is a new segment
    line('spawn').replace('t=10', 't=10'),
    line('spawn').replace('t=10', 't=0.2'), // clock rollback starts another segment
  ].join('\n'));
  const eden = data.maps.filter(m => m.map === 'mp_eden');
  assert.equal(eden.length, 3);
  assert.deepEqual(eden.map(m => m.spawned_entities), [1, 1, 1]);
  assert.deepEqual(eden.map(m => m.duplicate_projectile_spawn_events), [1, 1, 0]);
  const meadow = data.maps.filter(m => m.map === 'mp_meadow');
  assert.equal(meadow.length, 1);
  assert.equal(meadow[0].spawned_entities, 1);
  assert.equal(meadow[0].duplicate_projectile_spawn_events, 1);
  assert.ok(data.limits.some(s => s.includes('clock rollback')));
});
