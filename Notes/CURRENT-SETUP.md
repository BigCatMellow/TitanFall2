# Current setup

Updated 2026-10-28. Current normal deployment is the tested v23 Eden route repair, native SHA256
BC2C1019D27F537F075611ED6B68A75591D1F2F9924BA8700D82A757BB1000F7,
Northstar1.31.14. Human+15 bots,8v8,aim0.78, human tactical recharge0.5,
five-gun reload0.9 and human ADS/role trials enabled; bot balance opt-in stays0.
The normal shortcut defaults to Movement (movement/proximity fixes). Other
explicit presets add height response, roster, skills and personalities. Gated
crouch/global-route/jump/perception switches stay off. bot_eden_route_repair=1
enables the bounded repair only for Eden pilot navigation. Other maps and Titan
navigation keep baseline behavior. Both profiles use renamed BT7274
add-ons and current migrated saves. See [current rollout](candidates/bot-capability-v20-20261027/README.md).

Latest [Eden findings and runtime evidence](../research/route-continuity-v23-20261028/FINDINGS.md).
Repeated fixed-start off/on/respawn/off and lobby/Complex checks passed; effective
repair scope was0/1/1/0/0. Six normal save files and enabledmods were unchanged;
no existing gameplay-setting value changed. Isolated was restored to v20 native
3077878B...; test harnesses disabled and no game remains. Normal startup was
checked through launcher paths and matching validation receipt; no human match
has been played on the new deployment yet. Use the same solo shortcut.

Fresh private backup: before-eden-repair-v23-20261028-184241. To revert the native
and candidate flags while retaining current progress/settings, close the game
and run tools/Rollback-EdenRouteRepair.ps1 from the repository. Never restore
historical save_data over newer play. No antivirus settings were changed.

The Desktop **Northstar - Full Bot Trial (8v8)** shortcut explicitly selects
Full using the same current saves; the usual solo shortcut resets to Movement.
The first Full session is reviewed in
[played findings](../research/played-full-v20-20261027/FINDINGS.md). Preserve the
improved combat movement; investigate frag self-kills and Eden route stalls.
This review did not change the installed game.

The existing solo shortcut now starts the automatic text weapon notebook.
See [recording and reference stats](weapon-notebook/README.md). Current saves
are retained; no injector is enabled in normal play. Source checkout is
`%USERPROFILE%\northstar-crash-audit\TitanFall2-project`.
The v16 details below are historical; use the current rollout/status for changes.

## Historical v16 status (October 24)

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
- BT7274.WeaponReload 1.0.0 gives the local solo human 10% shorter normal/empty
  reloads on G2, Alternator, R-201 and CAR, preserving Speedloader. Other
  weapon stats and bots are unchanged. Read WEAPON-RELOAD.md for tests/rollback.
- Pilot tacticals: BT7274.TacticalRecharge 1.0.0 gives the local human half
  normal recharge time on all seven tacticals. Power Cell is preserved;
  bots/Titans/ordnance and ability effects are unchanged. All seven passed
  isolated game tests. Read TACTICAL-RECHARGE.md for tests and rollback.
- Solo Pilot/Titan loadouts now use the script-only BT7274.LocalPersistence
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
| Everyday solo profile | `%USERPROFILE%\northstar-crash-audit\local-test-profile` |
| Isolated test profile | `%USERPROFILE%\northstar-crash-audit\map-cycle-test-profile` |
| Solo launcher | `%USERPROFILE%\northstar-crash-audit\Play-Solo-Bots.cmd` |
| Desktop shortcut | `%USERPROFILE%\Desktop\Northstar - Solo Bots (8v8).lnk` |
| Source checkout | `%USERPROFILE%\northstar-crash-audit\TitanFall2-project` |
| Session logs | Each profile's `logs` directory |
| Before-v12 backup | This folder's `backups\v12-before` |

## User preferences and settings

BT-7274 wants lively solo battles, working Titan controls, moderate difficulty,
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

Sixteen is the total player count: BT-7274 plus 15 bots. The launcher explicitly
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

The `BT7274.BotLifecycle` server mod enables bot joins after the match intro.
The automated `BT7274.BotCycleTest` harness belongs only in the isolated profile.

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
%USERPROFILE%\northstar-crash-audit\TitanFall2-project,
https://github.com/BigCatMellow/TitanFall2 (public). Upstream330commits preserved;
initial local-project import c4145bc426758ab2453930054ea856e12534c531 pushed and
remote-verified. Source, BT-7274 add-ons, authored test harnesses, notes, expanded
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

Canonical source: %USERPROFILE%\northstar-crash-audit\TitanFall2-project.
Normal and working isolated now use decisions-v18-candidate native SHA256
F3C41DE2D11C84959454A16C8DCE9ED8B03BCD5E05E59090E32E87C6B78F3648.
Final BT7274.BotDecisions script SHA256
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
%USERPROFILE%\northstar-crash-audit\Notes\backups\before-v18-normal-deploy-20261025-194834.
All3CURRENT normal save files hash-identical during/after deployment; all25files
in LocalPersistence/TacticalRecharge/WeaponReload/BotLifecycle unchanged from
initial backup. No old save restoration or ns_resetpersistence. Rollback only
DLL/config/enabledmods; explicitly disable BT7274.BotDecisions1.0.0 when using
v16 (absence from enabledmods may auto-enable it). Preserve current save_data.

Startup correction: omitted profile Northstar.dll caused confirmed old-core
fallback1.30.2.0. Even after correcting to1.31.14, fresh candidate-v18-profile
remained startup-broken; do NOT use it or claim the remaining cause resolved.
A v16 control worked in the original isolated profile. It was backed up and
successfully tested with v18. ALL temporary native/schema/prewarm/UI-autoretry
work removed. No base-game writes. Core version verified from actual logs.
Dedicated startup attempts are invalid AI trials, not successful matches.

New background survey batch:
%USERPROFILE%\northstar-crash-audit\Notes\map-surveys\decisions-v18-all-maps-20261025-194900.
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
New ObserverDefaults switch disables bt7274_local_loadouts only for the inactive
survey observer; regular play profile is unchanged. New subcohort:
%USERPROFILE%\northstar-crash-audit\Notes\map-surveys\decisions-v18-observer-defaults-20261025-204736.
RunnerPID316532; HomesteadPID318188 (verify live).20maps remain including Homestead.
Homestead startup passed,16bots8v8, observer dead, scores advancing at20:49.
One successful control supports observer/persistence isolation, not a complete
root-cause fix. Label observer-restoration configuration separately from prior
trials. Normal3saves still hash-identical to before-v18-normal-deploy backup.
Current session pointer updated. stop-after-current.txt belongs in NEW batch.
Reports and sanitized aggregate progress in candidate SURVEY-PROGRESS.md/json.
2026-10-25 21:06 EDT — user authorized75-point unattended completion while asleep.
Homestead finished195-192 (IMC-Militia),15min, valid, no runtime errors detected;
third completed v18 map. Old observer-defaults queue stopped_by_request and
restored idle files cleanly. Preserve all3prior200-goal results separately.
New supervisor %USERPROFILE%\northstar-crash-audit\Notes\map-surveys\decisions-v18-overnight75-20261025,
PID320516 (verify live).19remaining maps, goal75perteam,15minfallback,16bots8v8
plus inactive observer, same frozen native/core/bridge/aim. Relic first,
child runner322112/game321636; actual MAP_SURVEY_BEGIN confirms engine75 and
harness75,16bots8v8, observer dead. No normal deployment/profile changes here.
Run-OvernightSurvey.ps1 reads private overnight75-request-20261025.json,
waited for old queue to finish, skips prior completed maps, supervises one-map
Run-CandidateSurvey.ps1 workers. At most2attempts/map, preserves failures and
continues after map-specific errors. Stops globally on frozen hash changes,
unrelated game/ownership conflict, failed config restoration or unknown faults.
Windows system-awake request active for supervisor only; released at exit.
All worker configuration restored between maps; normal save hashes guarded.
Six fixture checks passed (selection/order/exclusion/PlanOnly/bounds/core mismatch).
Live parent status.json includes child batch/PID/score. coverage.json aggregates
prior/new/failed/remaining; final summary.json distinguishes complete from
complete_with_failures. Failure is never successful coverage. Full private raw
logs remain local. stop-after-current.txt belongs in SUPERVISOR batch now.
Do not edit the frozen worker/native source while overnight queue is active.
See candidate OVERNIGHT-75.md and overnight75-start.json. Existing study data
continues to be telemetry only; do not infer win-rate/cast/geometry fixes yet.
2026-10-25 21:10 EDT — first75-point end-to-end success.
Relic ended75-18 at267.4s, score_limit, valid; reports generated without error,
idle profile restored, supervisor automatically launched Rise.4/22completed
including3prior200-goal matches and1new75-goal.18remain including running/starting
Rise. First completed shorter trial plus automatic handoff verified. Keep the
short lopsided Relic result distinct from full-length performance/balance claims.
2026-10-26 12:38 EDT — ALL22SUPPORTED MAPS COMPLETE.
Overnight supervisor stopped23:01Oct25 after16new matches (19aggregate). Traffic
had also completed75-71 at301.3s with valid BEGIN/RESULT/DONE and zero detected
runtime errors, but Stop-Process raced its natural quit, threw ProcessNotFound,
and prevented final cleanup/status/result persistence. Original failed child
state/stderr and overnight stopped_error are preserved; do not rewrite history
as overnight completion. Recovered Traffic as a separate derived record:
%USERPROFILE%\northstar-crash-audit\Notes\map-surveys\traffic-recovered-20261026-121941.
Recovery backup survey-cleanup-recovery-20261026-121941 includes CURRENT normal
and isolated saves plus prior files; only idle config/enabledmods/harness restored,
no saved data restored. Traffic reports regenerated from the original clean log.
Stop-OwnedSurveyGame now uses the original process handle with exact profile
argument/name checks and treats an already-exited handle as successful shutdown.
Eight regression fixtures cover the exact race/ownership/failure cases. Worker
persists result before cleanup and always records cleanup/restoration failures.

Final supervisor %USERPROFILE%\northstar-crash-audit\Notes\map-surveys\decisions-v18-last-maps-20261026,
request last-maps-request-20261026.json. Read20completed records; ran only UMA
(75-67,264.6s) and Coliseum (9-75,108.3s), finished12:30:31EDT with statecomplete,
zero failed attempts/report errors.22unique supported maps complete:3goal200,
19goal75. mp_coliseum_column still explicitly unsupported: no navigation data.
No game processes remain; idle cfg/enabledmods hash-restored; temporary awake
request released; all3CURRENT normal saves hash-unchanged during final trials.
Normal installed native F3C41DE2D11C84959454A16C8DCE9ED8B03BCD5E05E59090E32E87C6B78F3648
and bridge30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78 unchanged.

research/maps-v18-20261026 contains22round metrics, findings, manifest/hashes and
22sanitized compressed diagnostic logs (only exact BOT_/MAP_SURVEY_ whitelist
plus core/build headers). Private full logs, auth, personal saves stay local.
No script/native error detected in completed-round logs; earlier startup failures
and host cleanup exception remain separate.75goal median267.4s overall;
regular-map subset12rounds median332.85s; short/long goals and observer modes
remain separate. Strict phase-trimmed low-progress samples:WarGames330/4705=7.01%,
Eden113/2273=4.97%,Drydock50/1242=4.03%. WarGames/Eden shared cells warrant targeted
route work; Eden4096,-256,128 recurs in oldv16 too. No before/after causal claim.
Zero>5000Zoverhead target selections in16332visible pilot-engage snapshots,
not shot/cast/outcome proof. Four metric fixtures pass; three independent
PowerShell reference counts match. Public Eden archive replay regenerated matching
metrics, proving the published subset supports reconstruction. No visual watching.
Further tuning should use these map-specific leads; no native balance changes
were made during recovery/analysis. Latest session pointer now references completed
final supervisor; its current field is the last trial, NOT a live process.
2026-10-26 18:46 EDT — USER WEAPON BRANCH WORK IMPLEMENTED AND INSTALLED.
Integrated four remote branches with original commits/history preserved:
fix/weapon-mapping-coverage-20261026(fd63b9c),trial/ads-handling-20261026(d5ec903),
research/weapon-roles-20261026(da76335),tune/role-balance-v1-20261026(d569e4c).
Local integrate/weapon-stats-20261026 includes merges and rollout/test additions.
README conflict kept the completed map study and corrected the Volt/Alternator
naming. Native now weapons-v19-candidate, SHA256
9E8809146E17399B1CE572A5B479846C9A53633C48B7154A02159F47B19A4D6D.
Northstar1.31.14/core and bridge30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78 unchanged.
Native adds5standard profiles (Alternator/Mastiff/Devotion/B3Wingman/P2016),
25ordinary pilot profiles covered; special ColdWar/antiTitan policy unchanged.
Existing controller47058decisions/50000commands matchv16.46Rust/9suites and
17Node weapon/role checks pass; native distribution build passes.

Installed:BT7274.WeaponReload1.0.1,BT7274.WeaponHandling0.2.0,Solo.WeaponBalance0.1.0.
Human-only trial:Flatline20%less ADS recoil;Volt25%less ADS recoil;R9730%less hip
spread buildup/cap;Spitfire20%lower ADS movement scale;Flatline/G2ADS times0.75.
Actual Alternator now reload0.9 (2.30->2.07normal,2.70->2.43empty), preserving
Volt/G2/R201/CAR existing0.9. Speedloader composition0.63 and attachments checked.
Normal convars bt7274_ads_trial1,solo_weapon_balance1,solo_weapon_balance_bots0.
8v8/aim0.78/human tactical0.5/damage/RPM/magazines preserved. No default bot
loadout or bot aim buff. Source add-on defaults stayOFF; explicit normal opt-in.

Isolated weapons-v19-20261026-182749 PASSED:11actual bot gun classes, readiness,
lobby roundtrip/human+15bots,32reload/ADS/balance/automatic/strip cases, respawn.
22role field values match expectedmultipliers. Forced bot-modifier stripping
passed on Flatline/Volt/G2; actual physical dropping/pickup not exercised.
No script/native errors detected. No visual timing/feel or hit-rate/TTK study.
Normal startup weapons-v19-normal-20261026-183930 PASSED with902saved fields,
15bots+1human and3savefiles byte-unchanged. First watcher attempt had a parameter
typo, not gameplay failure; corrected and retained privately. No test session left
running, isolated harness disabled, normal launcher/shortcut unchanged.

Initial backup weapon-integration-20261026-181718; fresh deployment backup
before-weapons-v19-deploy-20261026-183629 under private Notes/backups. CURRENT
save_data copied for protection, never restored from older survey saves. Rollback
onlydeployment files; explicitly disable newHandling/Balanceversions ifrestoring
old enabledmods (absence can auto-enable). Keep current save_data.
Functional package source/staged/installed hashes match; docs/reference metadata
updated separately from executable fields. Public filtered runtime evidence,
normal-startup projection and hashes are in Notes/candidates/weapons-v19-20261026.
Map survey22rounds remainsFROZENv18(F3C41...), NOT a v19full-map validation.
Deeper balance study and user feel feedback remain pending; don't infer success
from paper DPS or effective variable arithmetic. Review current rollout README.
