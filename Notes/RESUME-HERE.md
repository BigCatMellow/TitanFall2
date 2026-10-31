# Resume here — Titanfall 2 / Northstar

Updated2026-10-30 22:06EDT for BT-7274. This is the current restart guide.
Read AGENTS.md and this file before older chronological notes.

## Immediate state

- Work is HELD for antivirus review. No game, Rust build, map queue or study
  coordinator is running. The authorized four-hour run NEVER STARTED.
- User reports Bitdefender flags naming pwsh.exe in the command line. The exact
  detection name, blocked command and alert timestamp are still pending.
- PowerShell at C:/Program Files/PowerShell/7/pwsh.exe has a VALID Microsoft
  Corporation signature (checked locally). That verifies the host, not the script
  it ran. Do not call the alert a confirmed false positive.
- No antivirus changes/exclusions, quarantined-file restores or detection evasion.
  Do not whitelist PowerShell, rename files to avoid detection or turn AV off.
- Isolated profile has been restored; normal setup and current saves preserved.
  The old Oct31 01:47EDT deadline does NOT authorize resumption in a later session.
  Resolve the actual alert and establish a fresh test window before more runs.

## Workspace and source

All paths below are under `%USERPROFILE%/northstar-crash-audit` unless stated.

- Active source worktree: `TitanFall2-integration-v28` (name predates this work).
- Active branch: `candidate/awareness-v31-20261030`.
- Last implementation commit before this guide: `2abc13a`, pushed to origin.
- Repository: https://github.com/BigCatMellow/TitanFall2
- Canonical checkout: `TitanFall2-project`, on an older candidate branch. It has
  intentional LOCAL changes to Notes/HANDOFF.md and tools/Start-SoloWeaponSession.ps1.
  Preserve them. Do not reset/overwrite the canonical checkout or silently build it.
- Active worktree shows M Cargo.lock from the existing Windows line-ending/index
  peculiarity; bytes are intact. Do not stage/change it just to clean status.
  SHA256 E4F8434813F688AF4FB5184EAEF4876A7F72F79C1D6B2A4DAB69C7BF2B89AE41.
- Old flagged untracked tools/Build-VerifiedWindowsCandidate.ps1 in canonical:
  do not execute, restore or stage it.

## Installed normal play

Profile `local-test-profile`; same existing solo / Full8v8 shortcuts.
Normal native is the tested v23 Eden-only route repair:
BC2C1019D27F537F075611ED6B68A75591D1F2F9924BA8700D82A757BB1000F7.
Northstar1.31.14; coreSHA
86007DD1DDAC9103508EECA520E2AB89B16DF92780A5F8A67497CCF29567EDB9.

New installed script-only BT7274.FragSelfDamage1.0.0 scales bot pilot own-frag
self-damage by0.25 (75%reduction). Human self-damage, damage to enemies, other
ordnance, Titans and friendly-fire rules unchanged. Configuration:
`bt7274_bot_frag_self_damage 1`, `bt7274_bot_frag_self_damage_scale 0.25`, log0.
52actual health checks across initial/respawn on Drydock/Glitch,11natural scaled
hits and lobby/map transition passed before installation. Current saves retained.
Receipt: local-test-profile/bt7274-frag-self-damage.json.
Backup: Notes/backups/before-frag-self-20261030-211049.
Immediate console rollback: `bt7274_bot_frag_self_damage 0`.
Persistent closed-game rollback: active source tools/Install-FragSelfDamage.ps1
-Rollback; never restore old saves. Don't run new scripts during AV hold.

Preserve8v8 human+15, aim0.78,0.8s firing warm-up, human tactical recharge0.5,
five-gun reload0.9, human ADS/role changes, bot weapon balance0. Full preset
adds roster/skills/personality. Native awareness / v29escape/crouch are NOT
installed in normal play. Global route/height/perception experiments stay gated.
All12normal guarded files, including current saves, matched the current backup.

## Awareness candidate and actual test coverage

User reported bots know their location too well. Code inspection confirmed
legacy selection can pursue enemies' CURRENT positions without seeing them.
Firing has visibility checks; unseen pursuit is the information leak being tested.

Default-off `bot_fair_awareness` candidate covers pilot sim6 only; Titans and
objective modes remain baseline. Only confirmed visible selected targets enter
per-bot last-seen memory (8bounded entries,4s default,1..12clamp). Unseen goals
stay fixed; reaching the last known area searches1.5s then forgets. Unknown
players do not supply pursuit goals. Patrols sample the local navmesh, not enemy
positions. No new sound/radar/Cloak/Pulse fairness guarantee or team sharing.

- Initial native CE1369E476F17FE9AA2EF82FFA5435499556C35C9AB78633DF9B95B96A125D22
  passed Glitch/Drydock off/on/respawn/off/lobby/new-map checks. Historical receipt:
  active source target/v31-smoke-session.json; public initial-lifecycle.json.
- Refined native522A8BC52838C4290A35878F5AD7C95040268BA1419BE0DA10F16A11C792F119
  compiled successfully, adds explicit seen_at logging and avoids clearing routes
  on mere visibility flicker. Its lifecycle was NOT started; don't label it tested.
- 134Rust tests/23suites plus migration/preset fixtures and121Node tests/24files
  passed. Final native changed logging/route handoff, not pure-memory algorithms.
- Source-only adaptive Start/Run-AwarenessStudy.ps1, Read-AwarenessValidation.ps1,
  Review-AwarenessRound.mjs and awareness-v31-cells.json were prepared. They have
  NOT been validated as a running queue. Gate/cleanup/deadline paths require review.
- Planned trials: frozen-native50-goal Full16bot observer maps; baseline vs4s,
  then2s/6s and separate4s+existing perception correction. First four Glitch,
  Drydock,WarGames,Complex; later Relic,Colony,AngelCity,Kodai. Adjust only between
  rounds; severe activity/stall cutoff; preserve normal profile; no automatic rollout.
  This plan is not an instruction to launch it during the AV hold.

Current private state: active source target/v31-active-session.json
(state halted_antivirus_review; request/batch null).
Backup pointer: active source target/v31-backup.txt ->
Notes/backups/before-awareness-v31-20261030-215020.
Isolated `map-cycle-test-profile` restored native:
3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89.
Harnesses and new self-damage mod disabled per-version there. Never resume
historical process IDs. No save restoration was performed.

## Data and research to resume

- NEW unreviewed played session: Notes/weapon-notebook/sessions/
  20261030-212703-ef66f160, log local-test-profile/logs/
  nslog2026-10-30 21-27-04.txt. Check recorder completion and hashes before analysis.
- Last reviewed played session:20261030-203850-13337652 (Drydock/Glitch), private
  replay active source target/played-20261030/FINDINGS.md. This predates installed
  frag reduction.46frag self-deaths vs21enemy; low progress0.58%/1.88%;44/46Glitch
  low samples had>=720deg yaw, no high jump fraction. Combat holds<9%near-stationary.
  Human pilot-victim credits18/3 and13/8 include Titan attacks, NOT scoreboard
  totals or pilot-only-attacker K/D. Only4clean human gun episodes: no damage/TTK
  balance conclusion.137whole-log notebook gaps; recorder/runtime errors0.
- `research/awareness-v31-20261030/README.md`: current candidate / AV hold.
- `research/gameplay-rework-v30-20261030/README.md`: installed frag change;
  future proposals reachable firing positions, failed-route recovery, position
  reservations and explicit locomotion action ownership. Proposals not installed.
- `research/tuning-v29-20261029/FINDINGS.md`: experimental escape/crouch native;
  short grenade results promising, navigation mixed; no normal promotion.
- `research/ui-map-left-inset-20261028/SQUARE-INVESTIGATION-20261030.md`:
  square minimap unresolved; size/zoom isn't shape. No HUD changes installed.
  Computer-use native pipe failed after retries. No live video watching occurred.
- Campaign tuning was discussed only. Current custom recharge/self-damage mods
  run SERVER && MP and do not apply to campaign. No campaign profile created.

## Resume sequence

1. Read this guide, AGENTS.md and the latest Notes/HANDOFF.md. Inspect actual
   processes/profile hashes/status; never infer current state from old receipts.
2. Get Bitdefender detection name, blocked command and timestamp. Determine
   whether it is script/behavior protection or a file verdict. Audit that exact
   command and its inputs. Valid host signature does not clear a command. Keep
   antivirus enabled; no broad exclusions or quarantine manipulation.
3. Useful work without execution: inspect unreviewed session completeness,
   source and research. Do not call native awareness fixes installed or proven fair.
4. Once the alert is understood/resolved, review and rerun lifecycle validation
   on the exact revised native. Use current backups, not historical saves. Review
   study orchestration before starting; obtain a fresh unattended duration.
5. Publish only reviewed aggregates/source. Raw logs, entity/account IDs, saves,
   game assets, meshes and binaries stay private. Do not change aim to mask AI
   information leaks or compensate for broken navigation.

Suggested first message in the next session:

> Continue the Titanfall2 project. Read Notes/RESUME-HERE.md in
> %USERPROFILE%/northstar-crash-audit/TitanFall2-integration-v28 and AGENTS.md.
> Preserve current saves and deployment. The four-hour run never started and
> awareness testing is held for a Bitdefender pwsh.exe command-line alert.
> Check actual state and help identify the exact detection before running tests.
