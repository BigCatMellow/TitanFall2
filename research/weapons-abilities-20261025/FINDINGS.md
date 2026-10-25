# Weapons and abilities: current changes and useful next steps

The strongest next improvement is more selective bot ability use and better
weapon/target transitions. Existing data does not support a broad damage,
accuracy or cooldown increase. This review changes analysis files only; no game
launch, deployment, save edits or map-queue resume occurred.

## Human weapon changes already present

[James.WeaponReload](../../James.WeaponReload/README.md) applies a 0.9 reload-time
multiplier to G2, Alternator, R-201 and CAR for the local solo human. These
archived engine-setting measurements are seconds without Speedloader:

| Weapon | Normal reload, before → after | Empty reload, before → after |
|---|---:|---:|
| G2 | 2.20 → 1.98 | 2.64 → 2.376 |
| Alternator | 1.50 → 1.35 | 2.00 → 1.80 |
| R-201 | 2.20 → 1.98 | 2.92 → 2.628 |
| CAR | 1.80 → 1.62 | 2.53 → 2.277 |

Speedloader composes: 0.7 × 0.9 = 0.63 of the unmodified reload setting. Eight
archived cases cover four guns with/without Speedloader, including all staged
reload fields. The harness also checked damage, fire rate, air hip spread,
magazine and current ammo unchanged, modifier non-stacking and disable/restore.
These are engine setting values, not new stopwatch measurements of animation
or time-to-kill. Bots are excluded; the archived run checked 15 unchanged bots.
Its injected transferred-CAR modifier-removal subcase was **not exercised**
(`bot_strip=false`); source implements it, but that run does not validate it.

## Human abilities already present

[James.TacticalRecharge](../../James.TacticalRecharge/README.md) halves recharge
time for Grapple, Cloak, Stim, Holo Pilot, Phase Shift, Pulse Blade and A-Wall.
It doubles refill rates and halves refill-start delays. Duration, effect,
range, charge count and cost are unchanged. This halves the recharge portion,
not the entire activation-plus-effect-plus-recovery cycle.

The archived probe checked six tactical weapons' refill multipliers, delay,
unchanged duration/ammo and ordnance rate, repeated application and disable.
It also timed Grapple from empty to full: 24.7s → 12.4s **in that Power Cell
configuration**, not a universal stock Grapple cooldown. Fifteen bots retained
their original modifiers. These are historical checks, not tests run today.
Titan abilities and ordnance receive no recharge adjustment.

## What the recorded weapon data actually covers

[Coverage](COVERAGE.md) reuses the same 16 phase-filtered recordings and joins
combat records to the exact epoch/slot/time of a live bot-pilot snapshot.
The primary-rifle evidence is R-201: 31622 matched cache samples in completed
controlled trials, 3187 in partial Kodai and 7642 in played rounds.

The broader join also retains `mp_weapon_defender` and `melee_pilot_emptyhanded`
records that narrower combat summaries filtered out. They establish recorded
cache names, not reliable current inventory or representative anti-Titan/melee
outcomes. v16 can retain cached weapon/clip/reload/tactic while bypassing the
decision block during boarding and some Titan encounters. No fresh-ammo or
empty-magazine incident rate can be inferred from those fields alone.

There is no representative primary SMG/shotgun/precision/projectile/heat-weapon
sample in this cohort, nor a shot/hit/damage/tactical-activation dataset. Do
not estimate accuracy, DPS, K/D, ability success or time-to-kill from these
snapshots. This limits balance conclusions even with many recorded maps.

## Bot ability decisions have specific source-level weaknesses

In [basic_combat.rs](../../bp_ort/src/bots/cmds/basic_combat.rs):

- Pilot tactical requests require visible engagement and a shared game-time
  window: `time as u32 % 25 < 10`. Cloak/Pulse Blade are requested in that
  window; Stim/Phase/Holo additionally require HP below 50. This is a repeated
  button-request schedule without a readiness check, not measured ability use.
- Grapple explicitly returns zero in that tactical match. A-Wall has no case.
  They are not handled by this pilot activation branch. Movement-aware Grapple
  needs safe landing/path checks before enabling it; A-Wall needs placement and
  facing logic. Recharge buffs alone will not add those decisions.
- Ordnance uses another shared window, `time as u32 % 25 < 3`, with selected
  classes. It does not assess readiness, trajectory or splash risk there.
- After decision processing, any remaining offhand request on a pilot clears
  `Attack`. That can remove the gun-fire command even when an ability is still
  on cooldown. The source confirms command suppression; the logs do not tell
  us which equipped abilities caused it or how many actual shots were lost.
- The reload decision's suppression branch clears **all** offhand requests,
  including defensive Stim/Phase requests. It does not distinguish a defensive
  tactical from offensive ordnance. Whether an ability can execute safely in
  a particular reload state needs an isolated engine test.
- Titan abilities mostly cycle through offhand slots by a local counter while
  shooting, with some class exceptions. Readiness/energy/threat-aware Titan
  use is a separate future investigation, not covered by human tactical buffs.

These findings are about current source behavior, not observed successful
casts. No readiness/activation telemetry exists in these v16 snapshots.

## Bot weapon decisions: useful existing behavior and gaps

[combat_decisions.rs](../../bp_ort/src/bots/combat_decisions.rs) already groups
movement engagement distances by weapon class, throttles empty-mag reload
requests, avoids low-ammo tactical reloads while a target is visible, reloads
low ammo after 1.25s without visibility, and bounds close retreat to 0.6s.
Those are movement/reload policies, not weapon damage or damage-falloff stats.
Heat/unknown weapons deliberately avoid generic ammo reload handling.

The native integration bypasses this block for Titan targets, owned pet Titans
and boarding. It also requests a weapon slot based on pilot/Titan target type.
Those transitions deserve direct current-weapon and reload observation before
changing anti-Titan reload, charge timing or switching policy. The diagnostic
v17 candidate helps mark current decision samples but remains undeployed.

## Priorities for a later authorized candidate

1. Record equipped tactical/ordnance, readiness, requested/issued actions and
   actual activation. Keep this distinct from repeated button requests.
2. Make requests readiness-aware and bounded, so an unavailable ability cannot
   keep unnecessarily suppressing gun-fire input. Preserve intentional engine
   restrictions and avoid repeated activations across long button holds.
3. Give defensive abilities an explicit policy during reload; evaluate Stim/
   Phase separately from offensive ordnance. Keep native bot cooldowns.
4. Measure current weapon, target type and firing/reload state across pilot/
   Titan switches. Add a representative weapon-class matrix before balance edits.
5. Leave Grapple/A-Wall automation for a movement/placement trial after route
   issues are understood. Preserve aim 0.78, 8v8 and existing human modifiers.

Removing unnecessary gun-fire suppression could increase bot pressure noticeably
even with aim unchanged. Test one bounded decision change at a time against the
same baseline before deploying it; do not bundle it with damage/accuracy buffs.

## Reproduce the offline audit

```powershell
./tools/Build-WeaponAbilityReview.ps1
```

The builder checks all 16 pilot cohort counts against the map review, rejects
duplicate combat keys and unexpected builds/diagnostic schemas, and verifies
the archived reload/refill/Grapple ratios and bot-exclusion completion records.
[Machine-readable coverage](coverage.json), [archived validation](archived-validation.json)
and [LF-normalized source/input hashes](provenance.json) are retained. Old test
harnesses are evidence, not automatically executed; no private saves are read.
