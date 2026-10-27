# Low-clearance navigation trial — 2026-10-27

UNDEPLOYED CANDIDATE. Windows DLL cross-build passed; not installed or runtime-tested.
`bot_low_clearance_trial` defaults to 0. No normal profile/config/save changes.

## Evidence and scope

User reports bots struggling to slide/crouch under obstacles. Source inspection
of `path_to_target` confirms normal waypoint following requests forward/sprint
and step jumps, but never Duck. The separate slide-hopper simulation is not the
normal mode-6 route follower. Existing recovery uses jumping/diagonal motion,
then a bounded backstep. This makes missing crouch traversal a plausible cause,
not a verified explanation for any particular map hotspot.

The historical survey and played-session review identify recurring low-progress
cells on Eden and War Games. They do not identify obstacle shapes or prove those
cells are crouch passages. Keep v18 bot-only and played v19 cohorts separate.

Source links:
- [Route follower](../../bp_ort/src/bots/cmds_utils.rs)
- [Candidate integration](../../bp_ort/src/bots/cmds/basic_combat.rs)
- [Pure policy](../../bp_ort/src/bots/low_clearance.rs)
- [Map survey](../maps-v18-20261026/FINDINGS.md)
- [Played review](../played-weapons-20261026/FINDINGS.md)

## Candidate behavior

- Mode-6 living pilot, Human nav hull, unseen target, actual route request,
  positive forward command only. Excludes combat, boarding and recovery.
- At most one probe batch per 0.2 game seconds while eligible. Open lanes use one upper ray; obstructed batches use
  ten existing filtered rays: one at feet+64, six lower rays at feet+8/+36 over
  three lanes (-16/0/+16 lateral), and three downward endpoint-support rays.
  Forward lookahead is 48 engine units. The upper ray must be obstructed; every
  lower ray must be >=0.98 clear and every floor ray strictly between0.01/0.95.
- These heights/widths are trial values, NOT verified standing/crouched hulls.
  Rays use the existing shot-mask trace helper. They can miss collision between
  samples, wrongly accept an opening, or reject a usable passage. No native ABI,
  navmesh file or path-filter changes are introduced. This is not a safe-hull
  clearance guarantee and must not be deployed on offline checks alone.
- Candidate crouch holds Duck, uses forward0.5, and removes sprint/jump/lateral
  inputs. No deliberate slide, extra speed, auto-grapple or jump spam is added.
  Existing momentum may still cause a slide; runtime validation must check it.
- Clear passage releases crouch intent. Stale (>0.25s), turned (>25degrees),
  displaced (>48units) or airborne observations cannot authorize crouching.
- A failed lower/support probe while active, <8units progress over0.6s, or a
  two-second attempt limit clears the old route and hands off to existing1.2s
  recovery. Another attempt is suppressed for4s. Timers reset on clock rollback;
  context cancellation releases intent without erasing cooldown; interruption of
  an active attempt also prevents immediate restarts.
- BOT_CLEARANCE logs probe classification, chosen intent, actual Duck output,
  attempt/failure counts and position at probe cadence and Duck transitions.
  Context cancellation is logged separately as intent=Cancel. Probe candidates and input requests are
  not proof of crouch posture or successful traversal.

Preserved: aim0.78, existing0.8s firing warm-up, damage, weapons, abilities,
coordination, team sizes, current saves, two-buffer pathfinder and map teardown.
Existing opposite-side combat retry remains unchanged. This trial targets route
traversal first, not a general combat-movement rewrite.

## Area avoidance decision

Do not blacklist a map or all low ceilings. A usable crouch link should remain
available; indiscriminate bans can disconnect routes or funnel all bots into one
lane. Replanning alone can return the same bad corridor.

After reproducing an actually non-traversable link, a follow-up can assign a
map/hash/hull-specific directed link cost or exclusion with alternate-route
validation. It must use native corridor filtering/costs (not only reject a final
waypoint), have an expiry/escape rule if temporary, and never match a broad XY
cell across multiple floors. No such area blacklist is installed in this trial.

## Isolated runtime acceptance (required before deployment)

1. Verify current profile ownership, processes, current save/config/DLL hashes,
   and matching Northstar1.31.14. Use working map-cycle-test-profile; do not use
   the abandoned fresh clone. Back up CURRENT state. Build with the repository's
   pinned Windows toolchain and run tools/Test-Project.ps1 first. The Linux pure
   policy tests are not a native DLL build.
2. Confirm startup and return-to-lobby with switch0. Set telemetry interval0.5
   only in isolated profile. Confirm normal gameplay settings are retained.
3. Identify actual crouch-only entrances in-game; record map, navmesh hash,
   approach/exit XYZ and direction. Use at least two distinct obstacles (prefer
   Eden/War Games if their geometry qualifies). Do NOT assert a recorded stall
   cell is a tunnel without observing it.
4. For each obstacle/direction, run20 baseline and20 candidate approaches from
   the same grounded position/loadout/speed with the same reachable target past
   the exit. Alternate blocks of5. Include stationary/walking and sprinting
   approach cohorts separately; measure actual posture/velocity, not just Duck.
5. Record entry-to-exit time, completion within5s, collision/no-progress spans,
   abort/retry counts, route taken and falls/deaths. A traversal success requires
   crossing a predeclared exit plane alive, remaining on the intended floor,
   and resuming the next waypoint. Duck input alone is not success.
6. Proposed pass: >=18/20 successful candidate traversals per obstacle/direction,
   at least5more successes than baseline OR >=25% lower median passage time
   if baseline already completes>=18/20. No falls, map escapes or stuck Duck.
   Repeat failures invalidate the claimed benefit; do not tune aim to compensate.
7. Negative controls:20 approaches each at a solid wall, a low opening narrower
   than the pilot, a ledge/drop, an ordinary standing doorway, stairs and an
   airborne approach. No crouch authorization from invalid/unsupported probes;
   never claim rays prove hull fit. Abort wall/edge candidate on any new fall or
   persistent collision. Ordinary-route median time must not worsen >10%.
8. Lifecycle: five repetitions each of respawn, weapon/loadout change, combat
   interruption, boarding/Titan transition, switch-off during passage, map swap
   and lobby return. No inherited crouch intent/cooldown across a new bot/map;
   no command override in combat/boarding/Titan states; no script/native errors.
9. Load test: three matched A/B rounds on Eden and War Games, then a full map
   coverage pass if accepted. Verify human+15bots8v8, aim0.78, firing gate,
   saves and profile restoration. At<=5batches/s/eligible bot, worst-case16bots
   add<=800rays/s. Measure server frame cost: median/p95 must stay within10%
   baseline, with no newly sustained frame-budget misses. Reject if over budget.
10. Review logs AND actual visual traversal independently before normal deployment.
    Keep failed runs and timeout counts. Existing weapon recording lacks shot
    accuracy and full traversal proof; it cannot replace this test harness.

## Rollback

Set bot_low_clearance_trial0 in the isolated profile. Next route command releases
this trial's Duck intent; confirm actual posture, command buttons and normal
navigation. Remove any persistent opt-in line. Close the game and restore the
pretrial native DLL if necessary; keep CURRENT saves. Verify old DLL/config hashes
and startup/lobby return. No normal deployment has been performed here.

## Results template

Run/build/core/map/nav hash:
Profile/input/target path/speed/attachments:
Switch A/B; preserved settings; save/config hashes:
Obstacle and direction | n | successes | median/p95 exit time | stalls/aborts | falls
Negative controls:
Actual posture and command evidence:
Lifecycle and switch-off:
Server frame median/p95 A/B:
Logs/video evidence references (private raw evidence remains local):
Decision: ACCEPT / REJECT / INCONCLUSIVE
Independent reviewer/date:
