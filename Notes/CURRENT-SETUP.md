# Current setup

Updated 2026-10-24. Deployment status must be checked here before further edits.

## Status

- Everyday solo profile: **combat-decisions-v16**, a reversible pilot combat
  trial on v15 navigation: weapon-aware positioning, ammo-aware reloads and
  corrected melee distance. 33 tests and two-map runtime checks pass.
  Gameplay improvement needs user feedback. Read RESULTS-v16.md.
- Solo/isolated SHA256: `C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075`.
- Regular Program Files profile remains **team-observer-v12**, SHA256
  `1183389B692F59758C569631F0C7BAB50703C7FB425212876DBB5ABB8DBE7D7A`.
- v11 SHA256:
  `DBE7301BFCAEF61E16165B3456D9F8EF851807DF2F64EDD768E2A9928EC63C48`.
- Northstar core: 1.31.14. OctBots is not active.
- James.WeaponReload 1.0.0 gives the local solo human 10% shorter normal/empty
  reloads on G2, Alternator, R-201 and CAR, preserving Speedloader. Other
  weapon stats and bots are unchanged. Read WEAPON-RELOAD.md for tests/rollback.
- Pilot tacticals: James.TacticalRecharge 1.0.0 gives the local human half
  normal recharge time on all seven tacticals. Power Cell is preserved;
  bots/Titans/ordnance and ability effects are unchanged. All seven passed
  isolated game tests. Read TACTICAL-RECHARGE.md for tests and rollback.
- Solo Pilot/Titan loadouts now use the script-only James.LocalPersistence
  1.2.1 add-on (902 fields, private-lobby saving, cache-only CLIENT/UI refresh
  and basic XP retention). Read PREVIEW-REPAIR-1.2.1.md and PERSISTENCE-REPAIR-1.2.md.
  The separate tiny aim trial
  is described below; 8v8 remains selected.
  See [local saving](LOCAL-LOADOUTS.md) for files, tests and recovery limits.

## Paths

| Item | Location |
|---|---|
| Game | `C:\Program Files (x86)\Steam\steamapps\common\Titanfall2` |
| Regular profile | Game directory + `\R2Northstar` |
| Everyday solo profile | `C:\Users\james\northstar-crash-audit\local-test-profile` |
| Isolated test profile | `C:\Users\james\northstar-crash-audit\map-cycle-test-profile` |
| Solo launcher | `C:\Users\james\northstar-crash-audit\Play-Solo-Bots.cmd` |
| Desktop shortcut | `C:\Users\james\Desktop\Northstar - Solo Bots (8v8).lnk` |
| Source checkout | `C:\Users\james\bp-ort-fork` |
| Session logs | Each profile's `logs` directory |
| Before-v12 backup | This folder's `backups\v12-before` |

## User preferences and settings

James wants lively solo battles, working Titan controls, moderate difficulty,
and enough bots to fill the map. 8v8 was enjoyable and is the selected size.

```
bot_manager_max 16
bot_manager_target 16
bot_manager_enabled 1
bot_cmds_type 6
bot_aim_penalty_speed -1
bot_aim_error_scale 0.78
bot_motion_debug 1
bot_team_coordination 1
bot_telemetry_interval 2
bot_escape_recovery 1
bot_combat_decisions 1
```

Sixteen is the total player count: James plus 15 bots. The launcher explicitly
uses `-maxplayersplaylist` and `+setplaylistvaroverrides "max_players 16"`.
Keep localhost binding `-ip 127.0.0.1 -port 37025`, public listing off, and the
existing solo authentication settings. Normal solo matches return to lobby.

At 20:02 on 2026-10-24, a user-requested tiny accuracy step was saved:
0.80 -> 0.78 (2.5% smaller random aim offsets). It is staged for next
launch/new listen server; ordinary map changes do not reload global
autoexec_ns_server. The running session was not interrupted and was last
observed at 0.80. Console bot_aim_error_scale 0.78 applies it live. See
REVIEW-20261024-1958.md for evidence, limits and backup/revert paths.

Activation verified at 20:24 on 2026-10-24: the repaired desktop/script
launcher started the solo profile; all 15 bots joined and BOT_MOTION showed
0.78. The 902-field loadout save restored with zero menu-cache mismatches.
Use desktop Northstar - Solo Bots (8v8). See LAUNCHING-SOLO.md.

The `James.BotLifecycle` server mod enables bot joins after the match intro.
The automated `James.BotCycleTest` harness belongs only in the isolated profile.

The v12 options are `bot_team_coordination 1` and `bot_telemetry_interval 2`.
Their plugin defaults are zero. Coordination affects legacy pilot mode 6;
Titan controls retain the existing selection/control path.

Coordination and snapshots are enabled in the everyday solo config. The
regular profile retains v12 and its option defaults unless explicitly
configured. The isolated profile currently uses v16 with coordination 1
and escape recovery 1. See RESULTS-v16.md for current combat tests; RESULTS-v15.md covers recovery;
RESULTS-v12.md is the historical coordination comparison.

[Latest verified Glitch replay](sessions/nslog2026-10-24_14-13-53/replay.html).
Source snapshot: `source-snapshots\v12-source-20261024-141554.zip` with its
manifest and tracked-change patch beside it. The source archive includes
untracked new modules/tests as well as the workspace sources.

Previous source snapshot: `source-snapshots\v15-escape-20261024.zip`.
Working pre-change backup: `backups\working-v12-before-recovery-20261024-151754`.
Close Northstar and run Restore-Working-V12.cmd to restore v12 bots/settings
without reverting newer loadout saves. `bot_escape_recovery 0` turns off the
backsteps. v14 target/cache experiments were rejected and removed from
compiled source; filenames containing "final" do not imply approval.

Current source snapshot: source-snapshots/v16-combat-decisions-20261024.zip.
Latest working backup: backups/before-combat-decisions-20261024-230020.
Use Restore-Before-Combat.cmd for the immediate pre-combat setup; it preserves
current loadouts/progress and the recharge/reload add-ons. Toggle the new
behavior live with bot_combat_decisions 0. See RESULTS-v16.md.

## Unattended map survey — 2026-10-25

A frozen v16 eight-map survey was launched in the isolated profile. Check
active-map-survey.txt, then that directory's main/progress.json before
operating the isolated game. Temporary setup:16 bots plus one dead spectator,
17 total client slots,8v8, aim0.78,200 team score limit and15-minute caps.
Normal solo profile/saves are unchanged. The watchdog restores the isolated
configuration and disables survey metadata when the full run exits. The
survey folder README documents validation, controls, outputs and limits.

Survey status verified: stopped on Eden particle-handle exhaustion after
Meadow completed its200-point target. Six maps not run. Isolated configuration,
persistence script/save and cycle metadata restored and hash-verified;
normal save unchanged. See active-map-survey.txt -> main/Summary.md.

Fresh Eden control launched08:19:18 on2026-10-25, using the unchanged v16
build,16 bots, aim0.78 and the same200-point/15-minute settings. Check
active-map-survey.txt -> main/progress.json before operating the test profile.

Fresh Eden control completed:161-145 in891.5s, engine time limit (not200 points), no FX/error. Pilot stall samples6.23%; known4096,-256 hotspot persists. All restoration hashes and normal save verified. User authorized3 automatic fresh-process followups:Eden repeat,Glitch,Angel City; active-fresh-batch.txt points to batch plan/status/Summary.md. Settings frozenv16/aim0.78/16bots/200goal/15min. Do not start another game or alter test profile during queue. This fresh pass does not prove carryover caused the prior FX failure.


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

2026-10-25 project migration: canonical source/research repo is now
C:\Users\james\northstar-crash-audit\TitanFall2-project,
https://github.com/BigCatMellow/TitanFall2 (public). Upstream330commits preserved;
initial local-project import c4145bc426758ab2453930054ea856e12534c531 pushed and
remote-verified. Source, James add-ons, authored test harnesses, notes, expanded
historical source, derived data/replays/plots and108 sanitized compressed logs
included. Private saves/raw buffers, installed game/third-party packages and
build/dump binaries stay local; import manifest records inclusions/exclusions.
Original backups/profiles/desktop launchers were not moved or overwritten.
Git author uses GitHub no-reply; only this exact checkout was added to real
user Git safe.directory because sandbox-created ownership differs.

Canonical tools/Test-Project.ps1 passed34 tests here; current-source whitespace,
370 JSON files and publication scan passed. Inherited automatic release/deploy
workflows archived .disabled, not active. Source is still diagnosticv17 candidate;
installed stablev16 unchanged. No game was launched and map queue remains paused.

Offline trend analysis completed in research/trends-20261025:16 recordings,
10 maps; cohorts separate, lobby/intro/post-match trimmed from played samples.
Stricter detector requires continuous sampled navigation in a10-13s low-net-
progress window and same live pilot. Fixtures cover navigation/engagement/life.
Controlled Eden aggregate7.21%; played Eden varies1.23%(latest) to9.72%(older).
The same old hotspot repeats, but latest round was healthier on the samebuild.
Do not interpret averaged6.2% played or changed measurement as a deployed fix.
Latest played Exoplanet1.03%; controlledCrash Site.40%,AngelCity.72%,Drydock.98%.
Overhead target selection persists in played Eden4.55%,Exoplanet5.87%visible
pilot-engage snapshots (selection, not proven firing). Weapon data stillR-201,
no reliable damage/hit/tactical-outcome study. See FINDINGS.md for priorities.
User explicitly requested OFFLINE review only; no launch/deploy/resume until asked.

2026-10-25 deeper decision review is saved under research/decision-context-20261025.
Analysis/tools may be pushed to GitHub per explicit user instruction; game/map
testing stays paused.235 deduplicated overhead target bursts,213 descending,
22 unclassified due to missing follow-up; observed high spans never exceed2s
(not actual durations). Watchdog stale-context behavior reproduced in pure Rust;
five strict compatible log cases, not proven false-alarm frequency. Production
code and installed profiles remain unchanged. See FINDINGS.md/METHODS.md and
verification.json for source equivalence, fixtures and reproduction details.

2026-10-25 weapon/ability analysis: research/weapons-abilities-20261025/FINDINGS.md
consolidates existing human modifiers, archived checks and16round weapon-cache
coverage. Source audit flags timed ability request/Attack suppression and blanket
defensive-offhand suppression during reload; impact needs new diagnostics.
No weapon/ability values, source behavior, installed files or saves changed.
Offline analysis/tools may be pushed; game testing/map queue remain paused.
2026-10-25 19:51 EDT — implementation, tests, deployment and survey restart.
This entry supersedes the earlier runtime-pending/preflight notes above.

Canonical source: C:\Users\james\northstar-crash-audit\TitanFall2-project.
Normal and working isolated now use decisions-v18-candidate native SHA256
F3C41DE2D11C84959454A16C8DCE9ED8B03BCD5E05E59090E32E87C6B78F3648.
Final James.BotDecisions script SHA256
30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78.
All four new switches enabled: bot_navigation_context, bot_target_eligibility,
bot_action_policy, bot_step_retry. Aim0.78, human+15bot8v8, existing human50%
recharge/four-gun0.9reload modifiers and launcher unchanged.

41 tests/8suites pass; current pure-controller47058decisions/50000commands
match v16. Native build passes. Full client integration run153058 passed
baseline/progressive switches, Eden/Complex/Canal, six guns/seven suits, lobby
and human+15bot return at15:48. Known-hotdrop selections11baseline/0filtered.
Final readiness-cost retest194409 passed matrix/lobby/15bots at19:48;866cost
samples,38unaffordable tactical observations,0incorrectly-ready. The full suite
used the earlier shared-energy check; final bridge adds ammo-per-shot cost.
An int/float compile error in that refinement was fixed before final test.
One quick launch intentionally stopped for argument-ordering error; corrected.
No native changes after the full suite. No damage/aim/cooldown rebalance here.

Normal deployed19:48; fresh private backup:
C:\Users\james\northstar-crash-audit\Notes\backups\before-v18-normal-deploy-20261025-194834.
All3CURRENT normal save files hash-identical during/after deployment; all25files
in LocalPersistence/TacticalRecharge/WeaponReload/BotLifecycle unchanged from
initial backup. No old save restoration or ns_resetpersistence. Rollback only
DLL/config/enabledmods; explicitly disable James.BotDecisions1.0.0 when using
v16 (absence from enabledmods may auto-enable it). Preserve current save_data.

Startup correction: omitted profile Northstar.dll caused confirmed old-core
fallback1.30.2.0. Even after correcting to1.31.14, fresh candidate-v18-profile
remained startup-broken; do NOT use it or claim the remaining cause resolved.
A v16 control worked in the original isolated profile. It was backed up and
successfully tested with v18. ALL temporary native/schema/prewarm/UI-autoretry
work removed. No base-game writes. Core version verified from actual logs.
Dedicated startup attempts are invalid AI trials, not successful matches.

New background survey batch:
C:\Users\james\northstar-crash-audit\Notes\map-surveys\decisions-v18-all-maps-20261025-194900.
Runner PID313660, initial Kodai PID307088 (verify live; historical once exited).
Read status.json/plan.json and parent current-v18-session.json.22maps,16bots
8v8+inactive observer,200team-point goal,15mincap, frozen DLL/core/bridge hashes,
fresh process each map. Kodai confirmed running,16bots and advancing kills.
Map mp_coliseum_column excluded because no navigation mesh. New v18 cohort;
do not merge with old v16 totals or restart old paused queue. Runner stops on
errors/uncontrolled population/noheartbeat/hash change. Create empty
stop-after-current.txt in THIS batch folder to pause after the current map.
Runner restores its pre-survey config/enabledmods/harness; it never restores
old personal saves. Test harness disabled in isolated idle config and absent
from normal. Never edit loaded DLLs/start another game while survey runs.

Telemetry only; no visual watching/recorder. Default bots still Grapple/frag,
whose legacy activation branch doesn't request them. Mixed weapons/suits are
test-only; no new Grapple/A-Wall automation. Pulse/shot/resource counters aren't
cast-success totals. Route hotspots/Titan-specific decisions/hide-and-seek
remain further work. Source, sanitized test diagnostics and reports are in
Notes/candidates/decisions-v18-20261025; private raw logs/binaries/saves stay local.
2026-10-25 20:49 EDT — survey follow-up.
First v18 batch completed Kodai129-163 and Boomtown169-161 (IMC-Militia),
both at15min. mp_grave is Boomtown, not Crash Site; conversational label corrected.
Homestead startup hit blank weapon name in intro hud_icon lookup at20:23.
Unchanged-build retry decisions-v18-remaining-20261025-204531 repeated the issue
in menu playermodel lookup; neither began a valid controlled match. No claim
that this is a native bot crash or that precise persistence cause is proven.
First batch profile_restored=false due exited-process enumeration race; after
confirming all games exited, idle cfg/enabledmods/survey script restored and
newly installed survey manifest moved aside. No save restoration. Second failed
attempt restored profile correctly. Runner now waits for owned exit and has
ResumeBatch support with matching native/bridge/core hashes and completed-map skip.
New ObserverDefaults switch disables james_local_loadouts only for the inactive
survey observer; regular play profile is unchanged. New subcohort:
C:\Users\james\northstar-crash-audit\Notes\map-surveys\decisions-v18-observer-defaults-20261025-204736.
RunnerPID316532; HomesteadPID318188 (verify live).20maps remain including Homestead.
Homestead startup passed,16bots8v8, observer dead, scores advancing at20:49.
One successful control supports observer/persistence isolation, not a complete
root-cause fix. Label observer-restoration configuration separately from prior
trials. Normal3saves still hash-identical to before-v18-normal-deploy backup.
Current session pointer updated. stop-after-current.txt belongs in NEW batch.
Reports and sanitized aggregate progress in candidate SURVEY-PROGRESS.md/json.
