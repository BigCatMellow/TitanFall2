# Isolated v22 corner trial — October28

**Final outcome:**29of32rounds/14matchedpairs completed; time-budget stop,
0detected game errors, both profiles restored to v20. WarGames improved on the
measured proxy in both repeats, Complex worsened in both. Guard staysOFF.
[Findings, caveats and next experiment](FINDINGS.md). Earlier progress notes
below are historical; current receipts must not be read as active processes.

BT-7274 authorized four hours of testing and shorter rounds after two more
played matches. Normal remains validated v20; current saves are protected.
The candidate adapts remote research/navmesh-corner-height-guard-20261028,
preserving its history. No normal deployment is approved by source/unit checks.

## Scope

bot_corner_height_guard defaults0. At1 it retains only nearby (<=45XY units)
ordinary intermediate pilot corners more than36units above the bot. Raw flags
must equal0 and jump type must equal0or255. Unknown metadata, start/end markers,
traversal flags/types, downward corners and Titans retain baseline behavior.
The36unit threshold remains provisional. It is not a full climb/jump controller
or a navmesh repair. Final consumed routes keep their existing handling.

Full preset/16bots8v8/inactiveobserver; aim0.78, firing warm-up, damage, weapons
and human buffs unchanged. Existing route guard/jump timing/crouch/perception
stay off. Failed v21 offhand safety and retarget switches explicitly stay off.
The A/B control uses the SAME v22 DLL with the corner switch0, not a v20/v22
build comparison. Keep played/bot-only,50/75point and native revision cohorts
separate. No visual watching or human difficulty claim.

## Provenance and first smoke

Current candidate native SHA256:
2B08DE76AB7A85C560F9DC9076F50233346EF1038A2C96B0F5BACD55AAB0A439.
Bridge1.0 SHA9C43719868D28121E6D59A07C3317882E135A50FF3C91AA1340A12C1219C4598.
Core1.31.14 SHA86007DD1DDAC9103508EECA520E2AB89B16DF92780A5F8A67497CCF29567EDB9.

The earlier BA66CF92... smoke passed all lifecycle checks with0detected errors,
but99/136rate-limited hold samples were start markers1:255. Most observed ends
were replans. This justified excluding start/end markers before the matrix;
it did not establish navigation improvement. Its phase aggregates are in
first-smoke/safety-review.json. Native/input flags and unequal phases are kept
separate. The refined native is undergoing its own full smoke; consult its
actual progress, not the earlier pass. Report successful advance, replan,
censored/missing ends and sustained low progress separately.

96Rust checks/18suites and migration/preset fixtures passed before first smoke;
the refined policy's7route tests passed again, including start/end exclusions.
Changed diagnostic/report tests,8validation-evidence cases,6planning/8cleanup
and queue-read/hash checks pass. Native builds use the existing release-debug
profile with original Cargo.lock, --locked --offline, antivirus enabled.
No old quarantined helper, security exclusion or dependency override is used.

## Matrix

Plan32rounds,50team points each,15minute map cap,16bots+inactiveobserver:
WarGames,Complex,BlackWaterCanal,Meadow,AngelCity,Relic,Homestead,Eden.
Each map has guard0/1 in two repeats, order alternates across maps and reverses
on repeat2. The requested time budget ends before BT-7274's expected return:
no new round with less than20minutes remaining before16:35EDT. This can leave
an explicitly partial matrix. Short rounds are screening; repeat denominators
and same-map comparisons matter more than number of matches.

Start only after same-native/core/bridge smoke passes control,guard,respawn,
disable,lobby/newmap and actual0/1readback. The separate NavigationV22 runner
gate preserves older v18/v20 validation requirements. Native errors, wrong
population/variants, frozen hash changes, restoration failure or normal-file/
save changes stop the queue. Existing process ownership and watchdogs apply.

Operational regression cutoff: after a matched pair with>=500live pilot samples
per condition, guard low-progress rate exceeding baseline by>5percentagepoints
AND>50% skips remaining guard-on rounds. Baseline variety continues. This is a
conservative stop rule, not a statistical finding. No automatic source edits.

Private receipt: target/v22-matrix-session.json. Private progress/raw logs remain
under the audit Notes/map-surveys parent. matrix-results.json contains sanitized
metrics/provenance only and declares partial/completed/skipped state. Stop with
stop-after-current.txt in the current batch. Cleanup restores isolated v20
DLL/bridge/config/enablement from the fresh before-v22 backup after owned games
close; it NEVER restores old saves. It refuses to overwrite a loaded profile
or unexpectedly changed native. Normal files are never deployed by this queue.

## Refined smoke result

Native2B08DE76... passed all five phases and lobby/WarGames->Complex transition
at13:14 with0detected runtime errors. Actual guard readback was0,1,1,0,1;
16bots/aim0.78 persisted, unrelated safety switches stayed off. This permits
isolated survey testing only. It does NOT establish gameplay improvement:
WarGames guard120s had78observed starts,77replan ends/1advance; the respawn
phase26replans. Complex90s had380starts/380replan ends. Replanning commonly
interrupts a guard, so matched movement outcomes must decide its value. Do not
reinterpret fewer start-marker holds as improved route completion.

## Publication failure and recovery

The first controller stopped during its second child because Set-Content hit a
sharing violation on the optional public matrix-results.json. The owned child
continued under its independent watchdog. This was a reporting-controller failure,
not a detected game crash; original failure records are preserved. No normal
file/save change was found. Initial-results.json remains a historical snapshot.

The controller now uses same-directory atomic JSON publication with bounded
sharing-error retries. Tests exercise real reader locks, replacement recovery,
persistent IO failure preserving old valid JSON, and immediate permission denial.
An unavailable optional public mirror is recorded privately but cannot stop
collection. Private status remains authoritative. Resume imports only complete,
restored, same-native/core/bridge/50goal/inactiveobserver child evidence and
recomputes reviewed metrics; completed map/repeat/variant keys are not rerun.
The regression stop rule is unchanged and also checks recovered matching pairs.
