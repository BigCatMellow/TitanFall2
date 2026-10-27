# Unattended map survey — 2026-10-25

Current full run restarted at 00:23:04 local time. Status is authoritative in
main/progress.json and main/Progress.txt; check those files for completion
or failure instead of assuming the game is still running.

## Plan

Meadow, Eden, Glitch, Angel City, Forwardbase Kodai, Rise, Relic, Wargames.
Each map: 200 team score target, 15-minute cap. In Skirmish/TDM the stock
script adds one team point per qualifying player kill. A timeout is a
capped observation and must not be reported as a completed 200-kill match.
Allow roughly one to two hours of matches plus report generation.

16 bots in two teams of 8, with the real client dead and spectating. The
isolated server has 17 client slots to accommodate that observer. This
slightly differs from normal solo's 15 bots plus an active human, but avoids
an idle human becoming bait and supports genuine 8v8 bot combat. The native
team chooser counts the connected observer; the harness checks/balances bot
teams during warmup before resetting scores and beginning measurement.

Frozen v16 DLL SHA256:
C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075.
Aim 0.78, coordination 1, escape recovery 1, combat decisions 1; native AI and
weapon selection unchanged. Standard Titan mechanics retained. No tuning
changes during collection. Movement/target/reload telemetry every 2 seconds,
score heartbeat every 5 seconds, and actual bot kill/death events/rosters.
Warmup kills are excluded by resetting scores after all 16 bots join.

## Isolation and recovery

Only map-cycle-test-profile was staged. Everyday local-test-profile, normal
launcher, saves and installed DLL were untouched. The real save SHA256 was
verified unchanged after staging. Config/cycle harness/test saves backed up
in backup/. No native bot source or DLL was rebuilt for this survey.

BT7274.BotCycleTest is temporarily disabled; BT7274.MapSurvey controls maps.
The final watchdog restores the original isolated autoexec/cycle-mod metadata
and moves the survey's active mod metadata out of mods after the game closes.
The observer uses privateMatchState and the stock spectator flow. The short
check exposed delayed respawn trying to respawn the observer every ~8 seconds;
the full harness cancels the post-death respawn thread with the same
OnRespawned signal used by stock respawn and clears respawn availability.

Watchdog: hidden normal-user PowerShell process. Prevents system sleep only
for its own lifetime, checks survey heartbeats/errors/wall-clock limits,
and can stop only the exact owned test process. A native/script error,
missing heartbeat, invalid population/observer state, or closure stops the
run and records the reason. It does not silently restart or tune the game.
Closing the test game manually is the supported early stop; the watchdog
then restores the isolated config. Normal solo launch waits until the test
instance is fully closed, due to the launcher's existing duplicate guard.

## Validation and output

smoke/ contains a separate two-map 20-score harness check, not 200-kill data:
Meadow 22–15 in 65.3 seconds, Eden 21–19 in 115.4 seconds. Balanced population,
kill JSON output, automatic transition, completed marker and shutdown passed;
no script/native errors. The spectator respawn correction was applied after
this check and is monitored on the full run.

main/ contains live progress and eventual results.csv, Summary.md,
summary.csv, raw-session.log, per-map raw logs/score and kill-roster JSON,
and reports/<map>/movement/replay.html plus combat and joined diagnostics.
Reports compare stall samples and rapid target switch-backs; those are
heuristics, not proof of a specific obstacle or bad decision. This run helps
map reliability, navigation and combat consistency. Difficulty against a
moving human still requires BT-7274's gameplay feedback.

Tools: Notes/tools/Start-MapSurvey.ps1, Watch-MapSurvey.ps1,
Summarize-MapSurvey.ps1, Export-BotSession.ps1, Export-CombatDecisions.ps1,
Review-CombatSession.ps1. The exact harness and watchdog are archived here.

## Startup correction

The first full-process restart stopped before measurement with a client
hud_icon lookup error. The test-only saved JSON contained empty weapon
entries after the spectator validation. That attempt is preserved in
attempt-1-startup-error; it is not a completed match. The normal save
remained hash-identical to its pre-survey copy.

The full run restores the valid test JSON from backup and uses a temporary
restore-only copy of BT7274.LocalPersistence's server file: SaveNow is empty,
while the established restore/client-cache path remains enabled. The game
therefore gets valid presets without writing spectator/transient fields.
The watchdog restores the original test server script and the two original
named JSON saves when the run exits. Native AI DLL and normal-profile
persistence code were not modified. This behavior needs investigation
before using normal autosave in another unattended spectator test.

Full-run startup check: bot teams 8/8; human alive samples after measurement 0; observer setup events 1; logged errors 0. Engine goal verified200. This verifies startup, not completion of the eight maps. See main/progress.json for current results.

