# Known issues and recovery

## Bot limitations

- **Hide and Seek compatibility — deferred, user-reported 2026-10-24.**
  BT-7274 reports bots do not seem to work in this mode. Not urgent; preserve
  the working solo setup and investigate in a future pass. Exact symptoms
  (not spawning, idle movement, or incorrect hider/seeker behavior), mode
  implementation and reproduction steps are not yet verified. Inspect
  mode-specific spawn/lifecycle gates, roles and target/team rules before
  choosing a fix; deathmatch behavior alone does not establish compatibility.
  Later telemetry: Meadow epoch 3 in the 18:42:30 session (mode hs) had 15
  bot slots but no alive samples in 549 observations. The exact role/spawn
  cause remains unverified; keep this mode out of normal combat comparisons.

- The legacy navigation mesh can miss pilot rooftops, obstacles, and airborne
  opponents. A failed route query can be followed by a successful recovery;
  failure count alone is not the number of permanently stuck bots.
- A short burst of recovery jumping can be legitimate. Repeated failure at
  the same position, high turn travel, and ten seconds without displacement
  are more useful signals to investigate together.
- Target sharing and spacing improve allocation, not squad-level planning.
  Bots do not yet have coordinated flanking routes or human-like squad orders.
- Titans retain legacy behavior; experimental OctBots Titan prototypes have
  not been validated here.

## If something goes wrong

1. Close Northstar normally before replacing DLLs. Confirm no test process is
   still running if Steam stays on “Stopping”. Do not terminate unrelated
   Steam or EA processes indiscriminately.
2. Double-click Capture-Latest.cmd to save the newest solo log and replay.
   The original logs are under the solo profile's `logs` directory. A `.dmp`
   beside the log is valuable for an actual native crash.
3. To restore the previous 8v8 solo build, close the game and run
   Restore-Previous-Solo.cmd. It restores the backed-up v11 DLL, solo config,
   and launcher; it verifies the DLL hash and does not erase saves.
4. See CURRENT-SETUP.md for exact hashes and profile paths. The regular
   Program Files profile has its own DLL backup, which may require elevated
   filesystem access to restore.

`%USERPROFILE%\northstar-crash-audit\Read-CrashDump.ps1` can inspect dumps.
Its raw stack-pointer candidates are not a trustworthy unwound call stack.
Keep matching DLL debug symbols and the exact build hash when interpreting one.

Avoid `ns_resetpersistence` as a generic troubleshooting step. It previously
crashed a session and changes player persistence. Do not reset saves merely
to investigate a navigation problem.

## Rejected v14 navigation experiments

The v14 failed-goal memory/route cache/breadcrumb retreat candidates produced
worse Eden low-movement counts and were not deployed to everyday solo.
Do not deploy archives/DLLs merely because their names include "final".
Read RESULTS-v14.md and verify the current approved hash in CURRENT-SETUP.md.

## Local loadouts

Direct-map solo sessions bypass cloud loadout persistence. The everyday
profile now uses BT7274.LocalPersistence; see LOCAL-LOADOUTS.md. Current version 1.2.1 stores 902 named equipment/basic XP fields locally; see PERSISTENCE-REPAIR-1.2.md. It does not save every statistic or purchase. Keep the mod folder
name and profile path stable. Presets lost before installation may need to
be recreated once. Never use the archived raw-buffer v13 restore experiment.

## Observer limits

The observer records game-state samples, not a video or screen feed. The
replay omits map geometry, so two nearby points can still be separated by a
wall. A stall flag is a diagnostic heuristic, not proof of a bug. Short turns,
animations and events between samples can be missed. Older v11 logs have
coarser samples and lack teams, human positions, targets and native alive state.

Comparison runs are short, include random spawns/encounters, and do not prove
causation or long-term stability. No claim of improved frame rate should be
made from the fixed simulation tick interval.

## Combat decisions v16

Intentional range holds may have low speed. Read BOT_COMBAT tactic and
reload fields alongside BOT_TRACE before calling these navigation stalls.
New side/back steps use point wall/ground traces, not a full hull or cover
planner. Gameplay improvements remain a trial; bot_combat_decisions 0
restores v15 combat. See RESULTS-v16.md and Restore-Before-Combat.cmd.

## Spectator survey save caveat — 2026-10-25

An unattended spectator test produced semantically invalid named loadout
JSON (empty primary weapon references) in the isolated profile, causing a
hud_icon lookup error on its next full-process launch. Normal-profile JSON
was unchanged. The active survey uses valid backup restoration plus a
temporary restore-only copy of its test persistence server script. Original
script/test saves restore automatically on exit. Diagnose and validate
spectator/transient-field saving before enabling autosave in a future
spectator survey; do not reset the normal save. See active-map-survey.txt.
