import test from 'node:test';
import assert from 'node:assert/strict';
import {instrumentFragSource} from '../tools/Prepare-FragLifecycleProbe.mjs';
import {parseFragStage, parseFragDamage, analyzeFragLog} from '../tools/Analyze-FragLifecycle.mjs';

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
test('diagnostic exceptions do not propagate through grenade callbacks', () => {
  const output = instrumentFragSource(fixture);
  assert.ok(output.includes('try\n    {'));
  assert.ok(output.includes('catch ( probeError )'));
  assert.ok(output.includes('BT_FRAG_PROBE_ERROR schema=1 stage='));
  assert.ok(output.includes('bt7274FragProbeState.errorLogged = true'));
  assert.ok(output.includes('#if SERVER'));
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

test('probe error marker prevents false conclusion of no grenade activity', () => {
  const failed = analyzeFragLog('[warn] BT_FRAG_PROBE_ERROR schema=1 stage=prep\n');
  assert.equal(failed.probe_errors_logged, 1);
  assert.equal(failed.probe_status, 'probe_error_review_required');
  assert.deepEqual(failed.maps, []);
  assert.ok(failed.limits.some(s => s.includes('invalidates absence-of-events')));
  const quiet = analyzeFragLog('unrelated server log\n');
  assert.equal(quiet.probe_errors_logged, 0);
  assert.equal(quiet.probe_status, 'no_valid_stage_events_cannot_infer_no_grenades');
  const valid = analyzeFragLog(line('spawn'));
  assert.equal(valid.probe_status, 'stage_events_present_runtime_validation_required');
});

test('standalone frag damage callbacks are counted without claiming health loss', () => {
  const lineDamage = (rel, victim, extra = '') => '[info] BT_FRAG_DAMAGE schema=1 map=mp_eden t=12'
    + ' attacker=41 victim=' + victim + ' inflictor=800 relation=' + rel
    + ' damage=45 ' + extra;
  const data = analyzeFragLog([
    lineDamage('self', '41', 'raw_private_id=41'),
    lineDamage('enemy', '42'),
    lineDamage('friendly', '43').replace('inflictor=800', 'inflictor=-1'),
    lineDamage('self', '42'), // malformed self/attacker relation, ignored
    lineDamage('enemy', '44').replace('damage=45', 'damage=0'), // ignored
  ].join('\n'));
  assert.equal(data.damage_maps.length, 1);
  const counts = data.damage_maps[0];
  assert.equal(counts.callback_events, 3);
  assert.equal(counts.self, 1);
  assert.equal(counts.enemy, 1);
  assert.equal(counts.friendly, 1);
  assert.equal(counts.missing_inflictor_handle, 1);
  assert.equal(counts.valid_inflictor_handle_at_callback, 2);
  assert.equal(data.damage_probe_status, 'damage_callbacks_present_not_confirmed_health_loss_or_deaths');
  assert.ok(!JSON.stringify(data).includes('attacker=41'));
  assert.ok(!JSON.stringify(data).includes('victim=42'));
  assert.ok(!JSON.stringify(data).includes('raw_private_id'));
  assert.ok(data.limits.some(s => s.includes('NOT proven to identify')));
});
test('damage probe faults and no-callback cases never imply absence of damage', () => {
  assert.equal(parseFragDamage('unrelated log'), null);
  const error = analyzeFragLog('[warn] BT_FRAG_DAMAGE_ERROR schema=1\n');
  assert.equal(error.damage_probe_errors_logged, 1);
  assert.equal(error.damage_probe_status, 'damage_probe_error_review_required');
  const quiet = analyzeFragLog('WNOTE_HIT source=frag');
  assert.equal(quiet.damage_probe_status, 'no_valid_damage_events_cannot_infer_no_frag_damage');
  assert.equal(quiet.damage_maps.length, 0);
});

test('signed encoded entity handles survive lifecycle and damage parsing', () => {
  const stage = line('spawn').replace('owner=41', 'owner=-2147483000')
    .replace('weapon=409', 'weapon=-2147482999')
    .replace('projectile=800', 'projectile=-2147482998');
  const damage = '[info] BT_FRAG_DAMAGE schema=1 map=mp_eden t=12'
    + ' attacker=-2147483000 victim=-2147482000 inflictor=-2147482998'
    + ' relation=enemy damage=45';
  const parsedStage = parseFragStage(stage);
  const parsedDamage = parseFragDamage(damage);
  assert.equal(parsedStage.owner, -2147483000);
  assert.equal(parsedStage.projectile, -2147482998);
  assert.equal(parsedDamage.inflictorKnown, true);
  const report = analyzeFragLog([stage,damage].join('\n'));
  assert.equal(report.maps[0].spawned_entities, 1);
  assert.equal(report.maps[0].invalid_spawn_handles, 0);
  assert.equal(report.damage_maps[0].valid_inflictor_handle_at_callback, 1);
  assert.ok(!JSON.stringify(report).includes('-2147483000'));
  assert.ok(!JSON.stringify(report).includes('-2147482998'));
});

test('missing sentinel, fractions and unsafe numeric handles never become valid entities', () => {
  assert.equal(parseFragStage(line('spawn').replace('owner=41','owner=-1')), null);
  assert.equal(parseFragStage(line('spawn').replace('weapon=409','weapon=41.5')), null);
  assert.equal(parseFragStage(line('spawn').replace('projectile=800','projectile=9007199254740993')), null);
  assert.equal(parseFragDamage('[info] BT_FRAG_DAMAGE schema=1 map=mp_eden t=12'
    + ' attacker=41 victim=42 inflictor=1.25 relation=enemy damage=10'), null);
  const missing = analyzeFragLog(line('spawn').replace('projectile=800','projectile=-1'));
  assert.equal(missing.maps[0].invalid_spawn_handles, 1);
  assert.equal(missing.maps[0].spawned_entities, 0);
});
