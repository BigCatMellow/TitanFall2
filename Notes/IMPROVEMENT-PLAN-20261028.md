# Improvement plan — October28

Evening update: the new Eden report took priority. A bounded Eden-only route
repair is now tested and installed, preserving the other gameplay settings.
See [results and remaining limits](../research/route-continuity-v23-20261028/FINDINGS.md).
Human Eden feedback and remaining choke points come next; broader map/type
rollout, grenade changes and weapon power changes are not implied by this fix.

## Earlier baseline play session

BT-7274 played the validated **Full v20** setup. Startup/readback
confirmed native3077878B..., Northstar1.31.14, Full preset and automatic normal-
play recording. The v22 corner guard is not installed: it regressed Complex.
Keep the user's active profile/DLL/config/saves untouched while playing. All
unattended queues from the earlier window are finished; do not restart them.

Play normally. War Games plus Complex or Black Water Canal are useful contrasts;
Meadow is a lower-stall comparison. A full CAR or R-97 round helps our SMG review.
The recorder handles timestamps; brief map/weapon/behavior feedback is enough.
These rounds are human-played v20 baselines, not a v22 on/off comparison.

## Priorities and acceptance

| Priority | Change to investigate | How we decide whether to keep it |
|---|---|---|
| 1. Grenade safety | Diagnose real toss versus cancel/drop; verify actual committed input; reject unsafe trajectories and use a checked escape from the observed projectile. | Fewer self-deaths per confirmed frag launch across repeated same-map tests, while retaining useful enemy grenade outcomes. Disabling throws is not a successful safety fix. |
| 2. Route continuity | Explain each replan and preserve a genuinely pending waypoint when appropriate. | Reduced sustained low progress and repeated replans on War Games/Eden, with no repeated regression on Complex/Homestead and no lifecycle errors. |
| 3. Weapon-specific decisions | Review SMG range bands, reachable closing/flanking positions, cover and reload decisions. | Better actual engagement positions/useful combat outcomes, without a rise in stuck loops or unfair first-contact shooting. |
| 4. Weapon measurements | Controlled fixed-range weapon tests plus validated opt-in bot discharge/ammo recording. | Reproducible timing/use measurements before changing a gun's damage, rate or handling. |

### First: add measurements that separate the hypotheses

Grenades: identify prepare, actual button hold/release, normal toss versus drop,
projectile/fuse, owner distance and final self/enemy outcomes. The previous
v21 input controller allowed continuation but did not always reassert the input
bit when the original skill policy omitted it. Test that integration explicitly;
it is a hypothesis, not proof of the cause of all513frag self-kills. Keep any
commitment bounded, freshness/weapon/life gated and immediately cancellable on
invalid state. Verify engine release before tuning pulse duration again.

Routes: label replans caused by moved target, explicit forced recalculation or
empty remaining list. Record the current pending corner, its height/type/hull,
progress and whether the requested goal really changed. An empty remaining
list can coexist with next_target_pos holding a popped corner; test that case.
Do not broadly cache stale paths. Preserve two-buffer/native teardown fixes,
reachability checks and bounded no-progress/timeout recovery.

Shots: the current magazine sampler is human-only, and its output is an
expenditure proxy. Add opt-in bot sampling with bounded cost and per-life/weapon
reset; validate any actual discharge hook against controlled ammo use, including
burst/pellet/multi-projectile cases. Do not call attack-input counts shots or
sampled hit ratios accuracy. Keep the existing human recorder working.

### Then test each behavior separately

Build a separate default-off candidate for one hypothesis at a time. Use a
fresh current backup, same-runtime guard-off/on control and explicit switch
readback. Check population, respawn, disable, lobby/new map, errors and current
save preservation before unattended comparisons. Keep old v20/v21/v22 cohorts
separate and preserve the failed/mixed evidence.

For a route candidate: start with3counterbalanced50point pairs on each of
War Games,Eden,Complex,Meadow (24rounds), then Homestead if a change touches its
behavior. Repeat or expand conflicting results. This is screening, not proof
from independent samples. Report per-map paired deltas/denominators, censored
ends and reasons, not one pooled improvement percentage. A route-only trial
keeps grenades/weapons/other movement switches fixed.

For grenade safety: use matched rounds on War Games,Canal and a close-quarters
map. First obtain reliable per-launch denominators. A working target is30%less
self-death per launch with retained useful throws; it is an evaluation goal,
not an expected or proven effect. A grenade-only trial keeps route behavior
fixed. The previous failing v21 timing candidate stays off.

### Weapon behavior before weapon power

CAR/R-97 had about66%/65%of visible pilot-target combat samples beyond the
current650unit controller far band. That band is not damage falloff or a
universal effective-range limit. Check whether the band itself is appropriate
and whether existing closing intent reaches usable positions; simply issuing
more forward input can make a bad route worse. G2's191kills also had more
observed engagement opportunities; kill totals alone do not justify a nerf.

For controlled gun measurements: fixed100HP targets, separate500/1000/1500unit
ranges, actual modifier/loadout snapshots, and body/headshot conditions kept
separate. Start with G2,CAR,R-97,R-201 and Hemlok. Aim for at least10valid runs
per tested condition and extend inconsistent results. Time from a verified
first discharge if available; otherwise retain the existing first-health-damage
span label. Test human bonuses and bot-native settings as separate cases.

## Playtest and rollout

After a candidate passes isolated checks, offer a clearly named reversible
human trial and verify the running build/flags/recorder. Compare similar maps,
weapons and presets, and use BT-7274's movement/fairness feedback alongside the
logs. No global corner guard rollout after the mixed v22 result. Keep8v8,
aim0.78,firing warm-up,current gun damage/RPM,human recharge/reload/handling
and loadouts fixed until a specific separately tested change is justified.
Current normal v20 remains the immediate fallback; rollback restores deployment
files only and never historical saves over current progress.

Evidence: [navigation matrix](../research/corner-height-v22-20261028/FINDINGS.md),
[weapon review](../research/weapons-matrix-v22-20261028/FINDINGS.md),
[latest played rounds](../research/played-full-v20-20261028/FINDINGS.md).
