# Handoff for future work

Everyday launch: desktop Northstar - Solo Bots (8v8), targeting the canonical
Play-Solo-Bots.cmd. Read LAUNCHING-SOLO.md for the separate profile, duplicate
instance guard and Northstar-specific quoting. Direct regular Northstar
launches do not select the custom profile. Never quote the entire -profile=
argument; quote only the value, or the raw parser retains a trailing quote.

Read CURRENT-SETUP.md, HISTORY.md, and the latest session's `metadata.json`
and `summary.json` before changing anything. Check the running executable,
its profile, the newest log's build ID, and installed DLL hashes. Old reports
are historical observations, not proof of the current installation.

## What James asked for

1. Improve organization: reduce dogpiling, target churn, and teammate crowding.
2. Observe actual bot behavior more closely, not merely successful bot joins.
3. Keep notes, logs, backups, and a reproducible way to resume or recover.

Latest balance preference: user reports ~40/6 K/D or ~40/11 when aggressive;
matches are close and feel fair. Avoid overcorrection. A single tiny
0.80 -> 0.78 aim-error step is active, verified in the 20:22:27 launch.
Read REVIEW-20261024-1958.md; keep 8v8 and other behavior unchanged.

Deferred request (2026-10-24): bots do not seem to work with Hide and Seek.
The user explicitly says it is not an issue right now, but wants it noted
and fixed later. Track it in KNOWN-ISSUES.md; no cause has been confirmed.

The working reference was v11 in an 8v8 solo match, aim-error multiplier 0.8.
The user last played Glitch successfully but still saw navigation problems.
v12 adds team-local pursuit claims and structured observation; its current
deployment/test status is in CURRENT-SETUP.md.

Previous: v15 was a reversible solo trial, using v12 target/path code with brief
diagonal backsteps after repeated pilot stalls. Read RESULTS-v15.md. v14
failed-goal/cache experiments regressed Eden and were rejected; do not deploy
their archives/DLLs. Restore-Working-V12.cmd uses the pre-change backup and
preserves current local loadout saves. The test suite now has 33 tests.

## Current combat trial — v16

Read RESULTS-v16.md. Solo/isolated now use combat-decisions-v16, hash
C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075.
The new bot_combat_decisions 1 adds weapon-range positioning, bounded
trace-checked steps, ammo-aware reloads and corrected pilot melee distance.
Keep 8v8, aim 0.78, and the player-only recharge/reload add-ons.
Thirty-three tests and Eden/Wargames runtime/toggle/map-transition checks
passed, including forced reloads and live Titan activity. User gameplay
feedback is still needed. BOT_COMBAT distinguishes intentional range holds
from pursuit stalls. Use Export-CombatDecisions.ps1 alongside normal replay.
Restore-Before-Combat.cmd restores v15 DLL/config while preserving current
saves/add-ons. Full pre-change source is backed up; don't reset upstream.

## Source and build

Checkout: `C:\Users\james\bp-ort-fork`. Upstream:
`https://github.com/catornot/bp-ort.git`, base HEAD `2d0a559`.
Changes are local and uncommitted; no GitHub fork/PR has been published.
Preserve existing edits. The source archive plus working checkout are both
needed context; do not reset the repository to upstream.

PowerShell build:

```powershell
$env:CARGO_PROFILE_DISTRIBUTION_STRIP='none'
$env:CARGO_PROFILE_DISTRIBUTION_DEBUG='2'
$env:PATH='C:\Users\james\Downloads\llvm-mingw-20261020-ucrt-x86_64\llvm-mingw-20261020-ucrt-x86_64\bin;'+$env:PATH
Set-Location 'C:\Users\james\bp-ort-fork'
& 'C:\Users\james\.cargo\bin\cargo.exe' +nightly-2025-09-11-x86_64-pc-windows-gnu build -p bp_ort --profile distribution --locked
```

Output: `target\x86_64-pc-windows-gnu\distribution\bp_ort.dll`.
Keep debug symbols. Run `tools\Test-BotBuild.ps1` from this notes folder and
`git diff --check`. There are native-independent tests for two-buffer output
bounds, jump release, movement progress, wrapped steering, and coordination.

## Deployment and observation

- Back up the active DLL, solo autoexec, and launcher before replacing them.
- Run new native candidates in the isolated profile first. Its separate cycle
  harness can change Relic to Wargames. Keep actual bot count and aim settings
  the same when comparing coordination on/off.
- Game writes in Program Files and normal desktop game launches may require
  the terminal tool's sandbox escalation. Restricted game launches produced
  a video-mode warning; normal desktop launches worked. That warning was not
  evidence of a bot crash.
- If stopping a test session, match its exact profile in the process command
  line and wait for process exit before replacing a loaded DLL.
- Only ship a build after tests and a real match check. Check movement,
  combat, team sizes, map-change cleanup, and absence of errors. A clean
  crash log alone is insufficient.
- Export logs with `tools\Export-BotSession.ps1 -LogPath '<log>'`. All reports
  stay local. The replay does not contain game terrain or video.
- Update CURRENT-SETUP.md, HISTORY.md, and session results after deployment.

## Important boundaries

James.WeaponReload 1.0.0 is a separate solo-human-only add-on: 10% shorter
reloads for G2/Alternator/R-201/CAR; no damage/recoil/fire-rate changes.
Eight native-runtime cases passed with/without Speedloader; 15 bots excluded.
Read WEAPON-RELOAD.md for scope, test limitations, backups and disable path.

James.TacticalRecharge 1.0.0 applies 50% shorter recharge to the local human's
seven pilot tacticals (user revised 30% to 50%). It is a separate script/KV
mod, not a native bot change. Read TACTICAL-RECHARGE.md before editing it;
Grapple uses player ClassMods, the other six use named weapon Mods. Preserve
existing modifiers, Power Cell, duration and bot exclusion. Actual seven-suit
tests and 15-bot exclusion checks passed. Disable via convar 0 and respawn.

The solo direct-map authentication path does not save normal cloud loadouts.
James.LocalPersistence 1.2.1 saves named Pilot/Titan/basic XP fields through
Safe IO and explicitly handles private-lobby entry and CLIENT/UI caches.
Read PERSISTENCE-REPAIR-1.2.md before changing it. Match-only server-field
tests missed the earlier lobby save gap; always test a real lobby edit and
the actual UI cache, plus a full process restart.
Background cache synchronization must not call UpdateCachedLoadouts_Delayed:
it clears 3D previews and caused the post-round tactical-equip race fixed in
1.2.1. Read PREVIEW-REPAIR-1.2.1.md for the reproduced control failure and
three real preview/equip passes. Preserve cache-only refresh.
Do not reuse the rejected raw-buffer v13 restore DLL, raw snapshots or capture
tool from backups/presets-before-v13. The stable DLL remains v12. Never copy
isolated loadout-probe JSON or James.BotCycleTest into the everyday profile.

The confirmed old crash was a native pathfinder buffer overflow. Disabling
name callbacks/client hooks was speculative. Authentication failure was an
external DNS failure at the time it was investigated; a reinstall coincided
with recovery and did not establish causation.

OctBots is an optional experimental rewrite. Read OCTBOTS-ASSESSMENT.md in
the source checkout. It needs matching plugin builds and its own navigation
data. Full OctBots navigation and a pilot/legacy-Titan hybrid have not been
validated. Team coordination does not repair missing map navigation coverage.

Latest read-only evidence: REVIEW-v16-20261024-2340.md covers three played
rounds in nslog2026-10-24 23-16-24.txt. Eden stalls were strongly localized
and affected six allies; Meadow had few stalls but many rapid target
switch-backs. Reloads looked healthy. Prioritize small target-consistency
and firing/step diagnostics, plus a separate Eden hotspot reproduction.
No new tuning has been applied from this review.

2026-10-25 unattended survey: read active-map-survey.txt and the pointed
folder's README/main/progress.json. Eight maps,200 team score or15-minute
cap,16 bots/8v8 plus a dead observer, fixed v16 and aim0.78. Only the isolated
profile is staged; don't launch another test or replace loaded files while
its watchdog is active. It generates per-map reports and restores isolated
config/cycle metadata on exit. Everyday solo remains unchanged. Score-capped
and timed-out rounds must be distinguished in analysis.

Survey startup correction: the first full launch stopped before measurement
because the spectator smoke run left empty weapon entries in test-only
saved JSON. Archived in attempt-1-startup-error. The restarted full run uses
valid backed-up test saves and a temporary restore-only persistence server
script. Watchdog cleanup restores the original script and named test saves.
Normal profile/save remained untouched and hash-verified. Read the survey
README before using persistence during further spectator tests.

Survey outcome checked: STOPPED EARLY. Meadow completed186–200 in682.5s.
Eden stopped around430s at last recorded86–67 on the600-particle-handle
limit (jump-jet wall-run trail at4120,-355,126), matching the known Eden
hotspot. Six maps were not run. All isolated config/script/save restorations
were hash-verified and normal save unchanged. No test process remains.
See the active survey directory's main/Summary.md and progress.json.

2026-10-25 fresh Eden-only control: active-map-survey.txt now points to
eden-control-20261025-081915. One fresh process,16 bots/8v8, aim0.78,
200-point team target/15-minute cap, unchanged v16 and effects. Main status
is in progress.json; isolated profile is temporarily staged while running.
The watchdog restores the original multi-map harness as well as config,
cycle metadata, persistence code and named test saves on exit. Normal solo
is unchanged. This compares against the prior Meadow->Eden FX failure.

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

Full-map queue startup verified10:23EDT: Black Water Canal reached measurement,16bots,8perteam,dead observer,goal/engine_goal200; BOT_MOTION confirms aim_error_scale0.78. Heartbeats/kills progressing, no reported failure or stderr. Both long-running workers active. Next steps can be read from active-fresh-batch.txt; no need to prompt for advancing maps.

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

2026-10-25 deeper offline decision review: user explicitly authorized pushing
analysis/tools to GitHub while keeping game testing paused. See
research/decision-context-20261025/FINDINGS.md and METHODS.md. New portable
tools/Analyze-DecisionContext.mjs checks all16 phase-window/overhead counts
against the earlier PowerShell builder; fixtures and deterministic regeneration
pass.235 overhead target bursts after per-entity/time deduplication:213 show
rapid descent,22 lack adjacent follow-up. All high bursts span one/two sampled
frames (zero/two observed seconds), not measured fixation durations. Incoming
pet Titans remain an inference; no direct transit classification or firing proof.
Several bots select the same entity; do not count685 bot snapshots as685 drops.
Watchdog helper reproduction confirms stale anchor time can survive a4s call
gap. Five strict compatible recovery log contexts (<=.25s preceding frame),
seven <=.5s,21 <=2.1s; nested counts, not confirmed false alarms/prevalence.
Original filtered excerpts retained. Watchdog/cmds_utils files and target
selection function match archivedv16 after line-ending normalization.
No production source, installed files, saves or gameplay values changed;
no game launch or queue resume. Installedv16/source diagnosticv17 unchanged.

2026-10-25 weapon/ability follow-up: research/weapons-abilities-20261025 records
the existing human four-gun0.9reload and seven-tactical0.5recharge changes,
archived8reload/6refill/1timedGrapple checks and limitations. Bot transfer-strip
runtime subcase was not exercised (bot_strip=false);15bots excluded in archives.
New offline builder joins16rounds to current phase windows, retaining
mp_weapon_defender/unarmed cache IDs omitted by narrower summaries; R201 remains dominant.
Source audit identifies fixed-time pilot ability request windows, no readiness
check, offhand requests clearing gunAttack and reload suppression clearing
defensive abilities. Grapple explicitly0/AWall absent in that activation branch.
These are source findings, not measured casts/lostshots. No gameplay changes;
next candidate should observe readiness/actions and improve decisions before
buffing damage/cooldowns. Source remains diagnosticv17; installs stablev16.

2026-10-25 user AUTHORIZED implementation/testing, then fresh map-by-map resume.
Source now decisions-v18-candidate;41offline tests and current-source47058
combat-decision comparison pass; native builds. Normal/former test profiles
remain v16; new candidate-v18-profile is disposable. Backup implementation-v18-
20261025-141109 preserves current DLLs/saves/configs. Candidate details/hashes in
Notes/candidates/decisions-v18-20261025/README.md. Runtime NOT yet validated.
Startup failures were missingPDEF in fresh profile; v16 control same profile also
stalled, dedicated log and user dialog confirm schema error. Runtime cache is
deleted on mod-load; do not keep blindly copying it before launch. Test-only
filesystem preflight now reads matching stock schema through existing interface.
No raw save/reset/schema-field edits or base-game writes. Current client retry
decisions-v18-20261025-150624. Do not deploy normal/resume survey until checks pass.

CORRECTION to startup diagnosis: fresh-profile construction omitted its root
Northstar.dll, so launcher fell back to game-rootv1.30.2 rather than1.31.14.
The old core did not enable the version-keyed copiedmods; only newbool add-ons
appeared in compiledRSON. MissingPDEF/missingfunctions were setup errors, not
valid AI trials. Copied matching1.31.14 runtime; regenerated enabledmods from
manifests. Removed temporary schema override/nativeprewarm and UI forcedmap
bootstrap. Launcher checks profileDLLversion; watcher checks actual logversion.
Normal/originalisolated profiles unaffected throughout. Runtime validation still
pending on corrected profile; refresh candidateDLLhash after clean rebuild.

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

2026-10-25 21:06 EDT — user authorized75-point unattended completion while asleep.
Homestead finished195-192 (IMC-Militia),15min, valid, no runtime errors detected;
third completed v18 map. Old observer-defaults queue stopped_by_request and
restored idle files cleanly. Preserve all3prior200-goal results separately.
New supervisor C:\Users\james\northstar-crash-audit\Notes\map-surveys\decisions-v18-overnight75-20261025,
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
C:\Users\james\northstar-crash-audit\Notes\map-surveys\traffic-recovered-20261026-121941.
Recovery backup survey-cleanup-recovery-20261026-121941 includes CURRENT normal
and isolated saves plus prior files; only idle config/enabledmods/harness restored,
no saved data restored. Traffic reports regenerated from the original clean log.
Stop-OwnedSurveyGame now uses the original process handle with exact profile
argument/name checks and treats an already-exited handle as successful shutdown.
Eight regression fixtures cover the exact race/ownership/failure cases. Worker
persists result before cleanup and always records cleanup/restoration failures.

Final supervisor C:\Users\james\northstar-crash-audit\Notes\map-surveys\decisions-v18-last-maps-20261026,
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

Installed:James.WeaponReload1.0.1,James.WeaponHandling0.2.0,Solo.WeaponBalance0.1.0.
Human-only trial:Flatline20%less ADS recoil;Volt25%less ADS recoil;R9730%less hip
spread buildup/cap;Spitfire20%lower ADS movement scale;Flatline/G2ADS times0.75.
Actual Alternator now reload0.9 (2.30->2.07normal,2.70->2.43empty), preserving
Volt/G2/R201/CAR existing0.9. Speedloader composition0.63 and attachments checked.
Normal convars james_ads_trial1,solo_weapon_balance1,solo_weapon_balance_bots0.
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

2026-10-26 20:06 EDT — AUTOMATIC WEAPON NOTEBOOK INSTALLED.
User explicitly chose automatic match recording. Solo.WeaponNotes1.0.0 is a
read-only SERVER/MP pilot damage/life/death logger in both working profiles.
Existing audit-root Play-Solo-Bots.cmd and Desktop shortcut now start the game
plus hidden Node collector through tools/Start-SoloWeaponSession.ps1. 8v8,
fullscreen/Eden/loopback, aim0.78, native9E8809..., all weapon/tactical/saving
add-ons and normal server CFG preserved:44existing gameplay files hash-identical.
No native build or gameplay stat change for this task. Test injector is disabled
in isolated enabledmods and absent from normal; no game/test remains running.

Notes/weapon-notebook has30pinned reference records, per-gun v19 runtime checks,
explicit steady-body ideal models, methods, source hashes and sanitized validation
projections. Runtime sessions stay LOCAL under audit Notes/weapon-notebook/sessions:
session.json, events.jsonl, summary.json, NOTES.md (15s refresh and final on exit).
Do not auto-publish raw sessions, account IDs, saves or auth. No video/audio capture.
Measured metric is first_positive_health_damage_to_death_s, NOT first-shot/trigger
TTK, shot count, accuracy or visual ADS timing. Numeric hitgroups/crit scales,
range/velocity, actual mod stack, humans/bots, map/mode and config are separated.
Exclude mixed/unknown/mod-changing/injured/healed/incomplete/forced/self/friendly
sequences; end-frame overlaps are conservatively incomplete. Small n exploratory.

Important runtime discovery: AddPostDamageCallback still sees PRE-DEDUCTION HP.
Use damage-final pre-hook + deferred WaitEndFrame health for nonlethal hits, killed
callback for lethal0. Preserve life/event guards and pending-overlap exclusion.
Synthetic TakeDamage has unknown weapon modifiers and correctly stays excluded;
real bot combat supplies known-modifier qualifying episodes. Do not fake current
attacker weapon attribution for delayed projectiles. Synthetic four-hit case
100->75->50->25->0 matched actual0.4s injection span, not nominal wait0.3 or R201TTK.
Initial Squirrel syntax/typing errors, blank test-loadout intro and WindowsPS
metadata issues fixed before final normal verification; failed attempts retained.

14offline checks passed:10episode/parser,3ideal-model,1live-tail/exit fixture.
Isolated session20261026-195319-09a37c7c:4synthetic cases+real combat,0callback
errors; reviewed snapshot117bot damage events/9qualifying episodes. Final normal
ACTUAL CMD/WindowsPS session20261026-200132-0b819922 PASSED:core1.31.14.0,
902named fields restored,39human+15bot frames,0script/native markers; finalized
29death records/8qualifying episodes, collector complete. No all-map/feel/balance
claim. Native unchanged; v18map survey remains historically separate.

Backup before-weapon-notes-20261026-193842 includes both CURRENT profiles' then
saves/config/enabledmods and prior CMD. No normal save restored. Final normal
JSON state changed in8XP/weaponXP/TitanXP/kill-counter/selected-slot fields during
sessions;0preset-definition changes. Keep CURRENT progress, not backup copies.
Isolated blank survey presets were seeded from CURRENT normal named copies only;
never copy isolated data back to normal. Rollback launcher and explicitly disable
Solo.WeaponNotes1.0.0 while retaining CURRENT save_data and weapon-v19 packages.

WindowsPS shortcut: no Get-FileHash helper available in its inherited module
context; .NET SHA256 used. ConvertTo-Json expands Get-Content string provider
properties: startup settings must be plain regex captures in an ordered dictionary.
Use canonical Resolve-Path backslash profile when stopping normal CMD-owned game;
Stop-OwnedSurveyGame exact argument comparison does not normalize slash styles.
A no-op ownership rejection must not be treated as successful shutdown. Final
owned game/hidden failed launcher processes closed, collectors finalized.

2026-10-26 21:03 EDT — FIRST PLAYED WEAPON/MOVEMENT/DIFFICULTY REVIEW.
User reported30+kill/6death dominance and wants better bot decisions/movement,
not unfair accuracy or being shot before responding. Reviewed completed real
session20261026-201056-50da37bd, native9E8809...v19, four maps.533pilot death
records/128qualifying health episodes,0logger and0script/native error markers.
Played data and historical22-map v18bot-only survey remain separate. No game
launched, no runtime files/saves/settings changed for this analysis.

Recorded human pilot-victim kills/pilot deaths:Eden14/2(R20114),Meadow16/1(Volt15,
smoke1),Traffic24/0(Kraber24),WarGames33/6(Spitfire26,SMR6,smoke1). These are
matching lethal pilot events, not complete scoreboard/totalK/D/win-rate data.
Independent PowerShell event count87/9matches Node attribution. Human clean
health episodes24:R2013median.234s,Volt7median.9455s,Spit14median.23515s;
these medians mix ranges/hitgroups and are NOT matched weapon rankings. Hit-event
range medians~958/1455/950units respectively. Keep damage/RPM as is. Kraber24hits
were all lethal, but projectile modifier stack unknown so0qualifiedtimings;
no accuracy or trigger/first-shot TTK claim. Only1clean bot->human death(.567s),
not enough to tune reaction windows.322/533death records multi-attacker.

General lead:45.6–54.1%of visible range-hold bot samples move<50u/s acrossmaps;
36.9–45.5%of contiguous hold samples have recent blocked-step counter increments.
Source zeroes movement when checked sidestep unavailable; airborne is also false.
Current fixedside.3/3.2sreversal/.6sretreat has no health/cover input. First proposed
trial: safe checked alternative/bounded reposition after sustained denied side
step, preserve grounded/cliff checks/trace caching/navbuffer safety. Log grounded
and denial reason. Keep aim0.78,damage/RPM and existing.8sfiring warm-up unchanged;
that sourcegate is not measured human-visible reaction time. Candidate NOT built
or installed; no extra aim pressure recommended.

Strict continuous-navigation low samples:Eden69/1712(4.03%),Meadow0/1404,
Traffic1/1641(.06%),WarGames132/4252(3.10%). Recurring Eden4096,-256,128cell15
samples/4slots;WG1664,-256,128also recurs, andnewlarger -2944,-128,-64cluster21
samples/8slots.104/132WG low-progress windows include>=720deg accumulated yaw;
0flaggedwindows havejump-button fraction>.2. More turning/recovery than sustained
jump spam in those windows; overlapping samples not independent incidents. Near-
zero LF stalls while human still dominates means routing alone won't fix combat.

8983readiness samples:Grapple/fragonly,0nonzero primary-attack-count observations,
source generates no automatic requests for them. Primary decision samples mostly
R201. Small symmetric Stim/Phase subset may be a SECOND backed-up isolated trial;
normal bots unchanged, Grapple traversal still unimplemented. Coordination is
claims/nearby spacing, not tactical formations/flanking. Max4–5bots sampledseeing
human atonce; don't remove sharing safeguards or focus everyone on human.

Reproducible tools/Analyze-PlayedWeaponSession.mjs +4meaningfulfixtures pass:
continuous turning vs jump requests;combat/death/gap/epoch guards;activeflag/native
human-target identity/trim;repeatedmaps andeventIDreuse. Replayed533/128matches
collector exactly. Public research/played-weapons-20261026 contains onlyderived
analysis/provenance hashes andfindings. Full18.8MB nslog/events/saves stayprivate.
Approximate activity bounds: preceding native frame atPlaying tolastdamage/death;
no exact winner/postmatch markers available. No visual watching occurred.

2026-10-27 — BOT CAPABILITY v20 SOURCE CANDIDATE, NOT INSTALLED.
User authorized implementing the review's recommendations as default-off
candidates (no merge/deploy). Seven switches, all 0 by default:
bot_nav_diagnostics, bot_route_guard, bot_jump_timing, bot_proximity_fix,
bot_perception_fix, bot_combat_movement, bot_crouch_recovery. Notebook 1.1.0
adds opt-in solo_weapon_notes_fire/solo_weapon_notes_viewkick. Aim 0.78, 0.8s
warm-up, damage/RPM, team sizes, saves, two-buffer pathfinder, teardown and
target sharing unchanged. Supersedes PR #5's ray-probe approach (stall-triggered,
engine stand/duck hulls, player-clip mask, failure memory). Offline only: 99 Rust
tests/15 suites and 8 Node suites pass; Windows-target cargo check clean; DLL
cross-built on Linux with stable+build-std (not the pinned toolchain; rebuild on
Windows). Hull-trace init, hull offsets, Detour partial bit, jump encoding and
the Squirrel sampler are runtime-unverified. Protocol, decision rules and
rollback: research/bot-capability-20261027/README.md. Run Experiment 1
(diagnostics only) before enabling behavior switches.
