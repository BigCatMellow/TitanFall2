# Change and investigation history

## Earlier setup and confirmed crash findings

Northstar and legacy bp_ort were installed for solo multiplayer with player
bots. OctBots was tried earlier and an old DLL remains in the 20261023 backup.
The current working profiles omit it.

An authentication failure named `r2-pc.stryder.respawn.com` and reported DNS
lookup failure. Public DNS checks at the time also failed. Later recovery
overlapped a reinstall, so those events do not establish that local changes
caused the authentication outage.

The repeated legacy spawn/path crash had a confirmed native memory error:
Titanfall's modified Detour `findPath` writes both polygon references and one
traversal byte per polygon, up to 256. An eight-byte stack placeholder for
the second output overflowed. The fork now owns two correctly sized buffers
and validates native output counts. See CRASH-FIX.md in the checkout.

## v7 — map lifecycle

Native navigation queries and bot state are cleared across server VM/map
changes. A server script publishes match readiness after the intro, joins
are spaced 0.5 seconds apart, and fake-client creation runs after the server
physics callback rather than the general HostState frame. Polling the script
VM from that frame was rejected after failed tests. Thread IDs alone did not
prove a worker race. A seven-bot Eden → Relic → Wargames test passed.

## v8–v10 — movement

Fixed a jump hold that never decreased, corrected obstacle cooldown handling,
and stopped requesting jumps continuously on flat routes. Navigation uses
feet rather than eye position. v9 exposed a partial-route loop and was not
deployed. v10 detects actual horizontal progress independently of waypoint
replacement and initiates bounded recovery. Seven-bot movement and combat
were observed across Kodai, Relic and Wargames. Individual stalls remained.

## v11 — skill and steering

Added `bot_aim_error_scale 0.8` to the relaxed solo preset: 20% less angular
aiming error, not a measured 20% change in hit rate. Fixed yaw turns across
the -180/+180 boundary, bounded navigation turns, skipped nearby duplicate
nodes, and reduced repeated recovery jumping. Eleven regression tests passed.

## 8v8 configuration

Raised manager max/target to 16 total players (one human, 15 bots). The solo
launcher explicitly requests the 16-player playlist cap. Fifteen bot joins,
movement, and combat were observed; James reported the result was great.
The code's 32-client ceiling has not been stress-tested as a solo match.

## Glitch round reviewed on 2026-10-24

From 13:48:28 to 13:56:25, the v11 log recorded 15 bots and 702 movement
samples. Of 537 samples with movement input and positive health, 11 had less
than 50 horizontal units of displacement. There were 299 failed route queries
and no logged crashes/script errors. Health alone was an imperfect alive-state
proxy in that old log. These figures show local route trouble, not a precise
measure of how well the bots coordinated.

## v12 — coordination and observer

Adds soft, team-local pursuit claims, target continuity, immediate-threat
priority, and light teammate separation for pilot deathmatch. Claims expire
or clear on death and reset per map. It never excludes the only enemy. Titan
controls keep their prior selection path. A disabled-convar comparison uses
the original target selector.

Adds structured two-second snapshots, native alive/team/Titan information,
target identity/visibility, target switches, path requests/failures, recovery
events, jump commands, turn travel, and spacing counters. A local exporter
produces CSV/JSON and a standalone replay. Seventeen regression tests pass.
The isolated enabled/disabled runs each spawned 15 bots on Relic and another
15 after changing to Wargames, with no logged script errors, access violations
or panics. The Relic enabled run showed fewer target switches and low-movement
samples; see RESULTS-v12.md for counts and comparison limits. The DLL was
installed in the regular and everyday solo profiles, with coordination and
two-second snapshots enabled in the solo preset. A visible Glitch handoff
match was opened for a third-map check.

## 2026-10-24 — local loadout saving

The user reported Pilot/Titan presets disappearing between solo instances.
The direct local connection uses insecure authentication, whose core
persistence-write path has no disk-save implementation. Added the Squirrel
James.LocalPersistence 1.1.0 add-on using named persistent fields and Safe IO.
It saves edits and changed fields on a one-second poll, restores on connect,
and retains a previous snapshot. Empty enum values use stock helper empty
strings so the JSON encoder does not drop them. The v12 bot DLL and chosen
8v8/0.80 settings remain unchanged. See LOCAL-LOADOUTS.md for exact evidence.

A preceding raw-buffer v13 prototype failed an isolated restore with an
empty weapon-name client error. It was rejected, never deployed to everyday
solo, and removed from active source/tools. Diagnostic artifacts remain in
backups/presets-before-v13 and must not be used as supported recovery files.

## 2026-10-24 — working backup and recovery trials

Made the verified working-v12-before-recovery-20261024-151754 snapshot
(2671 files, source/runtime/configs/loadout saves and SHA256 manifest).
Restore-Working-V12.cmd restores solo bots/settings while retaining newer
loadout saves. Broad v14 target-memory/cache/retreat candidates regressed
Eden in short tests and were rejected; none reached everyday solo.

Restored v12 target/path code and built escape-recovery-v15, adding only a
bounded diagonal backstep after repeated local pilot stalls. Twenty tests
pass. Eden/Wargames each spawned 15 bots, with movement/combat activity and
no logged errors; 35 backsteps activated. Low-movement counts were mixed
(31/16 versus disabled 1/29), so a general improvement is not established.
Enabled v15 as a reversible solo playtest at 16:00:43. Normal Eden restored
440 loadout fields and spawned 15 bots. Regular Program Files stays v12.
Exact hashes, source archives, observations and limits are in RESULTS-v15.md.

## 2026-10-24 — loadout persistence repair 1.2.0

Found that the private lobby bypassed the connection callbacks which started
the local save loop. Added local ready-handshake/player detection, an
initialization guard and explicit CLIENT/UI cache refresh. Expanded named
saves to 902 fields with basic XP/levels. Tested full restart and actual
lobby loadout edits carried into Rise; actual UI cache showed zero
mismatches. Updated only the add-on in everyday solo and reopened Rise.
Original real saves/add-on were backed up first. See PERSISTENCE-REPAIR-1.2.md.

## 2026-10-24 — deferred Hide and Seek issue

James reports bots do not seem to work with Hide and Seek. Recorded as an
open compatibility issue for future investigation; explicitly not urgent.
No reproduction/cause is confirmed and no game settings or code were changed.

## 2026-10-24 — review and tiny aim trial

Reviewed the full 18:42:30 session: four regular Meadow rounds had 2
low-movement samples among 6879 alive-bot samples; Deck had 40/1053,
concentrated in two neighboring areas. Hide and Seek had no alive bot
samples and remains a separate deferred issue. User reports ~40/6 K/D or
~40/11 while aggressive, with close/fair matches and a preference against
overcorrection. Full scorecards were not recorded.

Backed up solo config and staged only bot_aim_error_scale 0.80 -> 0.78,
2.5% smaller random aim offsets. No native code, damage, population, movement
or progression change. Not applied to the current process: the global cfg
runs on next launch/new server, or console bot_aim_error_scale 0.78 applies
live. See REVIEW-20261024-1958.md for results and exact backup/revert paths.

## 2026-10-24 — independent desktop solo launcher

User's direct Northstar launch selected regular R2Northstar, bypassing the
custom solo profile. Updated Play-Solo-Bots.cmd with required-file checks,
duplicate-instance guard and explicit local profile/16-player launch args;
created desktop Northstar - Solo Bots (8v8). A test exposed raw-parser
quoting: quote only the -profile= value. Corrected it and verified a fresh
launch with 15 bots, live aim 0.78, restored 902 fields and no logged errors.
The folder was writable; no ACL changes or save resets were needed.
Read LAUNCHING-SOLO.md. The assistant is not required for future launches.

## 2026-10-24 — post-round pilot preview race

The background cache refresh added in 1.2.0 also cleared 3D previews. This
erased a tactical preview before SavePilotCharacterPreview and triggered
the user's no-model animation error. Reproduced preview clearing in an
isolated control, then replaced the helper with cache-only updates in 1.2.1.
Three actual preview/equip cycles passed after a match-to-lobby transition,
including medium, with no script errors. Backed up saves and original code,
updated the real add-on, and reopened the lobby. Native bots/tuning and
saved equipment were unchanged. See PREVIEW-REPAIR-1.2.1.md.

## 2026-10-24 — half pilot tactical recharge

User changed the requested recharge reduction from 30% to 50% before
installation. Added James.TacticalRecharge 1.0.0 as a separate script/KV mod
for the local solo human's seven tacticals. Isolated actual loadout tests
passed for all seven with Power Cell; Grapple refill measured 24.7 -> 12.4
seconds. Other six refill rates doubled, delays halved, effects/ammo and
ordnance unchanged; repeated application did not stack. All 15 bots excluded.
Archived test harness/results and restored the normal isolated cycle script.
Real save matched backup before restart; normal launch restored 902 fields
with zero menu-cache mismatches and applied the Pulse Blade recharge mod.
Native v15 DLL, 8v8 and 0.78 aim tuning preserved. Source and real-save backup
paths, test log and disable instructions are in TACTICAL-RECHARGE.md.
The canonical solo launcher also includes the earlier requested -fullscreen
flag; video settings were set to fullscreen without changing resolution.

## 2026-10-24 — modest human weapon reload improvement

James approved the weapon-review proposal. Added separate James.WeaponReload
1.0.0: G2/Alternator/R-201/CAR reload times multiplied by 0.9, human-only, multiplicative
with Speedloader. No damage, fire rate, recoil, spread, magazine or handling
change. Eight actual runtime timing cases and 15-bot exclusion passed;
source/deployed hashes match. Test-harness attachment/type errors and their
isolated-save effects were corrected before deployment; real saves always
matched backup. Preserved v15 DLL, 8v8, 0.78 aim and 50% tactical recharge.
Normal fullscreen launcher started 22:14:19. Read WEAPON-RELOAD.md for logs,
measured timings, limitations, backups and disabling.

## 2026-10-24 — pilot combat decisions v16

James chose combat decisions next. Backed up all working source and both
v15 DLLs/configs/saves, then added optional weapon-range positioning,
trace-checked brief retreats, ammo-aware reload timing and a corrected
pilot melee distance formula. Preserved navigation/detour fixes, Titan
combat, 0.78 aim, 8v8 and the player-only bonuses. All 33 tests and native
build/checks passed. Eden ran with flag off then on; Wargames exercised
shotgun/G2 ranges. Both forced empty-mag reloads refilled; 30 bot joins,
15 per map, Titan activity and map cleanup observed with zero errors.
Deployed as a reversible trial and reopened normal fullscreen solo 23:16:24.
902 save fields restored with zero cache mismatches. Details, snapshots,
hashes, test limitations and rollback are in RESULTS-v16.md.

## 2026-10-24 — review of three played v16 rounds

Read-only review saved in REVIEW-v16-20261024-2340.md. Eden had254/2453
pilot stall samples,211 in one small area affecting six human teammates;
Meadow rounds had1/1504 and4/1580. Approximately31% of Meadow target
changes rapidly reversed. Reloads showed no persistent starvation loop.
Flagged a close-range paused-firing/blocked-step case for better diagnostics.
No DLL/config/save changes. Fresh replay and joined analysis are archived.

## 2026-10-25 — unattended map survey started

James authorized letting bots play varied maps to a200-kill target. Added
an isolated script harness and hidden watchdog, preserving the v16 native
build. Two-map short-score validation passed; corrected spectator delayed
respawn handling for the full run. Launched eight maps with16 bots,8v8 plus
observer, aim0.78,200 team score limit and15-minute caps. Saves/config of
normal solo untouched. Check active-map-survey.txt and live progress for
actual completion; reports, raw logs and cleanup are automated.

The survey's first full launch stopped at startup on empty test-save weapon
references after the spectator smoke test. Archived it, restored valid
isolated JSON, and made only the test server persistence module restore-only.
Restarted the full survey at00:23:04. The watchdog restores the test script
and named saves on exit; normal profile files were unchanged.

## 2026-10-25 — survey stopped early on Eden effects limit

Meadow reached186–200 in682.5 seconds. Eden's last heartbeat was86–67
at430.1 seconds, then the client hit the600 FX-handle limit while starting
P_enemy_jump_jet_WR_trails at(4120,-355,126.09), the known navigation
bottleneck. Watchdog halted the test; six maps were not run. Verified all
isolated cleanup hashes and unchanged normal save. Preserved partial logs
and generated map reports; outcome summarized in the survey main/Summary.md.

## 2026-10-25 — fresh-process Eden control

User authorized Eden alone from a fresh launch to separate map-local effects
from carryover. Launched08:19:18,16 bots/8v8, aim0.78,200-point target and
15-minute cap, unchanged v16 DLL/AI/effects. Reused verified observer and
restore-only persistence safeguards. Backed up isolated files and original
multi-map harness. Actual outcome pending; active-map-survey.txt is the pointer.

Fresh Eden control completed:161-145 in891.5s, engine time limit (not200 points), no FX/error. Pilot stall samples6.23%; known4096,-256 hotspot persists. All restoration hashes and normal save verified. User authorized3 automatic fresh-process followups:Eden repeat,Glitch,Angel City; active-fresh-batch.txt points to batch plan/status/Summary.md. Settings frozenv16/aim0.78/16bots/200goal/15min. Do not start another game or alter test profile during queue. This fresh pass does not prove carryover caused the prior FX failure.


Map context: user asked us to find map information ourselves. Added map-context/README.md, offline validated MSETv5/DNAVv13 small-hull geometry for Eden/Glitch/Angel City, PNG overviews and Eden stall overlay. No mod/native/nav changes. Source references and limitations in README. New code lead: cmds_utils route-point consumption uses horizontal distance only, possibly skipping vertically separated waypoints; broad target Z projection and unused traversal metadata also deserve investigation. These are hypotheses pending active-hull/route traces, not proven causes. Fresh batch runnerPID246268 is active; first repeatEden PID248076. Read active-fresh-batch.txt -> status.json/Summary.md; root control remains complete, not active. Batch auto-restores/verifies after each map and runs analysis without prompts.


2026-10-25 navigation follow-up: read REVIEW-20261025-NAVIGATION.md. Eden repeat completed102-146 at891.5s (time cap), no error, all8 restoration checks true. Glitch running, Angel City queued. New offline waypoint reader distinguishes actual next route point from BOT_TRACE enemy coordinates: hotspot usually22-23 units above, repeatedly points350-420 units away near(3765,-253,150); no proof of vertical waypoint skip. No gameplay/native/nav/save changes. Both v16 DLLs and normal save hash-verified. Read-only analysis workerPID251472 watches archived results and writes active batch/analysis/status.json,Summary.md, per-map waypoint reports/nav overlays. Bounded70min; never controls game. Match runnerPID246268 remains independent. Read active-fresh-batch.txt for current states rather than relying on this historical timestamp.

2026-10-25 10:13 verified completion: the entire fresh-batch-20261025-083855 queue and read-only analysis worker finished at09:27. Eden102-146 and Glitch125-180 both reached891.5s engine caps; Angel City200-150 reached score limit in757.7s. No recorded match failures or analysis errors. Pilot stall sample rates:Eden8.38%,Glitch1.36%,Angel City0.85%; these are sample fractions, not percentages of bots or unique incidents. All24 per-match restoration checks passed. Solo v16 DLL and normal named save hashes still match baseline. Former runner/report worker PIDs are no longer active. No new gameplay changes were deployed. Primary next reproduction target remains the repeated Eden obstruction/route transition; target reversal frequencies alone do not establish a global combat problem. Reports: active-fresh-batch.txt -> Summary.md and analysis/Summary.md.

2026-10-25 full installed-map survey launched10:22EDT at the user's request.
NEW ACTIVE QUEUE: active-fresh-batch.txt points to all-maps-20261025-102025.
22 fresh-process trials:15 full-size maps,6 Live Fire arenas, original Coliseum.
Inventory has23 installed MP maps; mp_coliseum_column has no installed custom
navigation file and is explicitly unsupported/unbenchmarked, never a pass.
Unchanged v16, aim0.78,16bots/8v8 plus dead observer, TDM200-point goal and
15-minute cap. Small-arena trials measure controlled8v8TDM, not their original
special modes. Expected about6hours; all trials auto-advance after per-map
cleanup/hash checks. Normal files also backed up to baseline/ and checked.
RunnerPID256508; read-only report workerPID256908; first gamePID255920,
watchdogPID257172, Black Water Canal. Historical PIDs must be rechecked.
Status: queue status.json/Summary.md and current map/main/progress.json.
Analysis: analysis/status.json,Summary.md and per-map waypoint/nav overlays.
Analysis worker bound expanded from70minutes to25*mapcount+30=580minutes,
and its reader/exporter sources are snapshotted in batch/tools with hashes.
To stop cleanly after current match, run the batch's Stop-after-current.cmd;
runner records stopped_by_request and analysis worker recognizes that state.
Don't launch a separate game or edit the isolated profile while queue active.
No native/gameplay/navmesh changes deployed. All original stable settings and
loadouts remain protected. Read the batch README/inventory/plan for protocol.

2026-10-25 11:34 parallel combat review: read combat-review-20261025/README.md.
New read-only Review-TargetSwitches.ps1 separates prior-frame pilot/Titan
contexts and preserves unknown combat freshness. On Colony/Complex, Titan-
context reversals are about59%, pilot-context about23-34%; these snapshots
are not proof of bad decisions.179 cached combat snapshots during embark in
first3 maps demonstrate the freshness limitation. All observed pilot combat
weapons there are R-201; broader weapon behavior needs a separate matrix.
Read-only combat workerPID118992 is active and has processed4 maps without
errors. Its source snapshots/status/Summary are under active batch/combat-evidence.

IMPORTANT SOURCE/DEPLOYMENT DISTINCTION: checkout now builds observation-v17-
candidate. Installed solo and isolated DLLs remain frozenv16 hashC6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075.
Candidate only adds exact actor=pilot/titan to decision logs, active=0/1 to
combat snapshots, a per-command freshness flag, and distinct startup label.
No decision/aim/navigation/persistence tuning changed.34 tests/7 suites and
native distribution build pass;47058 decisions across50000 commands match
v16 outputs/state in a differential comparison including bypasses/time resets.
Candidate NOT DEPLOYED and NOT runtime-tested. Saved in candidates/observation-v17-20261025 with before/after4sourcefiles,full source zip,verification.json.
Candidate DLL SHA256:9FB6E5ACE50E858607D2CD3B04F592ABE45F1C5DB0E99EE54CDAC525DC74E2F9.
Do not copy target/distribution into a profile or interrupt current map queue.
After queue, a real isolated diagnostic/toggle/map-transition check is needed.
Compiler ran1job below-normal priority during Crash Site; no FPS claims.

User asked whether we can visually watch/follow bots. Computer-use SKILL and
runtime docs read; @oai/sky imported through node_repl successfully, but
sky.list_windows failed twice: native pipe unavailable / os error2. No game
screenshot or UI input occurred. We have NOT visually watched the matches.
Current ability is log reconstruction and inspection of supplied/captured
frames. Bot-follow recordings plus synchronized logs would help discriminate
collision geometry, target switches and boarding failures. Desktop capture
connection must work before live screen inspection/camera control is claimed.

2026-10-25 user explicitly paused all map testing to play. Queue is stopped_by_request,
not active;5 completed matches plus user-interrupted Kodai at last141-98/745.1s.
All84 restoration checks across6trials passed. Original watcher-closure reason
is retained; Kodai is annotated interrupted_by_user, NOT a spontaneous crash.
Both navigation/combat report workers completed6reports and exited. No auto-resume.
remaining-maps.json has17trials including Kodai; resume requires a fresh batch
and CURRENT save/config baselines, because normal gameplay may update saves.
Do NOT restart the old runner or restore survey baselines over new user saves.

User requested their session: stable-v16 normal solo launched12:03:26EDT,
PID273256, Eden,fullscreen. Log nslog2026-10-25 12-03-27.txt confirms902 named
loadout fields restored and15bots+1human. last-play-session.json holds details.
No candidate/aim/nav changes were deployed while the user plays.

Archived review completed: review-paused-20261025/REVIEW.md and map-comparison.json
cover10complete recordings/9distinct maps plus partial Kodai. Crash Site.42%,
Angel City.85%,Drydock1.09%; Eden6.23-8.38% remains the shared route hotspot.
New stronger combat lead: XY-only candidate/vision range admits overhead
get_pet_titan targets; Canal slot9 selected target393331 atZ11127→7205→2002
while itself nearZ-100, marked engage. Consistent with incoming Titan, exact
transit kind not yet logged. Over5000-above selections occur in8.49% of Canal
visible pilot engage snapshots,7.11% Colony,7.0-7.29%Eden,6.82%Angel City.
These are selected-target snapshots, NOT proven firing/wasted shots. A future
eligibility fix must address visible AND pursuit fallback, verify transit status,
and preserve reachable nearby threats. No patch deployed. Other priorities:
Titan-specific continuity diagnostics, Eden/Complex obstruction traces, safely
trying the opposite combat strafe when the selected step is blocked, then a
weapon-class matrix (current survey pilots only observed R-201).

Computer Use missing from user's visible catalog; native screen helper failed.
No live visual watching or installed recorder. Automatic time-matched bot-follow
recording remains future work. Diagnosticv17 candidate remains NOT DEPLOYED;
source checkout/target build are candidate, installed profiles remainv16.
