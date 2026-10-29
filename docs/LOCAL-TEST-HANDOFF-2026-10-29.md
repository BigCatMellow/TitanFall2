# Local-agent test handoff — 2026-10-29

**Status: source candidate ready for LOCAL VALIDATION, not a validated release.**
GitHub PRs #9, #10 and #11 were reviewed and merged into main. PR #12 was reconciled with that main history and submitted for source-only merge. Before playing, check the actual HEAD and install state again; a Git commit is **not** a deployed DLL or Northstar mod. Use owner alias BT-7274 in all output.

## Scope and immutable baseline

- Core: Northstar 1.31.14.0; normal installed v20 DLL SHA256 `3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89`. These are **historical installed baselines to check**, not fingerprints of the new build.
- Default game: 8v8 = one human plus 15 bots; aim error multiplier 0.78; firing warm-up 0.8 seconds. Do not change damage, RPM, human reload/ADS, other abilities, bot count, persistence, normal profiles, or CURRENT saves.
- Original pre-PR backup: Git branch `backup/pre-bot-ai-20261029` pointing to `1b223ee62e5ebad23f4c35954601313e579ef64d`.
- Normal user profile: `%USERPROFILE%\northstar-crash-audit\local-test-profile`. **DO NOT deploy here.** Use `%USERPROFILE%\northstar-crash-audit\map-cycle-test-profile` only. Check `Notes/CURRENT-SETUP.md` and `Notes/candidates/bot-capability-v20-20261027/README.md` for verified setup and rollback. Do not copy old saves into either profile.

## First commands from repository root (PowerShell / Windows)

```powershell
git fetch --all --prune
git checkout main
git pull --ff-only
git status --short
git rev-parse HEAD
node --test tests/bot_ai_trial.test.mjs tests/tactical_recharge_source.test.mjs
$env:RUSTUP_TOOLCHAIN='nightly-2025-09-11-x86_64-pc-windows-gnu'
./tools/Test-Project.ps1
$env:CARGO_PROFILE_DISTRIBUTION_STRIP='none'
$env:CARGO_PROFILE_DISTRIBUTION_DEBUG='2'
cargo +nightly-2025-09-11-x86_64-pc-windows-gnu build -p bp_ort --profile distribution --locked -j 1
```

LLVM-MinGW's bin directory must be on PATH (or set `LLVM_MINGW_BIN` for the PowerShell test runner). Native output: `target/x86_64-pc-windows-gnu/distribution/bp_ort.dll`. A successful build does **not** install the DLL. If the working tree is dirty, stop and preserve local changes; do not reset/force-push or overwrite. Record the new DLL SHA256 with `Get-FileHash`. If any test fails, keep the installed baseline and investigate before proceeding.

Offline validation status before this handoff: Node analyzer fixtures (eight) passed in the research workspace; a Pulse Blade static regression fixture was added but not verified on Windows. The Rust test harnesses are authored but not executed in this remote editing environment; no GitHub CI or Northstar runtime certification is claimed.

## Source candidates and their flags

| Source | Behavior | Default/requirements |
| --- | --- | --- |
| PR #9 | `bot_corner_height_guard`: don't consume a horizontally-close waypoint when more than 36 units vertically separated | Default 0; actual game threshold is provisional |
| PR #10 | `BT7274.TacticalRecharge` 1.1.0: local human Pulse Blade regen native; other six tacticals unchanged from 0.5x recharge | Only install in isolated profile; test Power Cell, new loadouts and bot exclusion |
| PR #11 | Larger square inset minimap research and integration fragment | **Not** a standalone mod; no actual HUD integration yet |
| PR #12 | `bot_nearest_pursuit`: avoid farthest-first uncoordinated pursuit | Default 0; preserve coordinated/visible policies |
| PR #12 | `bot_stall_target_recovery`: four-slot per-bot strike memory and brief pursuit cooldown | Default 0; never exclude visible opponents |
| PR #12 | `bot_frag_safety`: conservative frag eligibility and six-second request spacing | Default 0; requires both `bot_skill_use 1` and `bot_action_policy 1`; lower grenade requests is not automatically better |
| PR #12 | `bot_frag_input_probe`: log final frag offhand press/release commands | Default 0; command pulse is **not** a confirmed grenade release |
| PR #12 | `bot_low_clearance_approach`: grounded double-confirmed hull sweep triggers bounded Duck command | Default 0; no verified slide, grapple, wall-run or jump-code mapping |
| PR #12 | `bot_nav_diagnostics` enhancement: raw `BOT_CORNER` flags/jump class, `BOT_STALL` context | Existing default-off switch; codes remain unverified |

All new bot behavior switches default to 0 **in source**. Verify effective runtime values after server autoexec and map changes rather than relying on code defaults. Check that installed presets do not silently enable experimental behavior.

## Ordered isolated runtime validation

1. **Preserve** the current isolated profile DLL, mod packages, configuration, local progress and any pending edits, recording hashes and backup paths. Close Northstar, validate core/mod versions. Never replace normal/current saves with archived ones.
2. **Baseline**: after installing only the new candidate into the isolated profile, verify all new behavior switches at 0 and reproduce 8v8, aim 0.78, firing warm-up 0.8s, human mod constraints, bot spawn/respawn, lobby→Eden→other map→lobby, no native errors, no map teardowns leaks, and CPU/p95 versus the known-good v20. Prefer baseline Movement first.
3. **Navigation A/B**: match map, loadout, duration/round goal and other flags. Run Eden and War Games, with Complex and Meadow controls. Test `bot_corner_height_guard 1`, `bot_nearest_pursuit 1`, `bot_stall_target_recovery 1`, `bot_low_clearance_approach 1` **individually** before combinations. Log `BOT_PATH`, `BOT_CORNER`, `BOT_STALL`, `BOT_CORNER_HOLD`, `BOT_CLEARANCE` and `BOT_ROUTE_COOLDOWN` with `bot_nav_diagnostics 1` only for diagnostic cohorts. Verify visible engagement, correct target switching, failure memory expiry, crouch release, waypoint progress, full/partial routes, post-respawn reset and frame overhead. A logged command is not proof of physical traversal.
4. **Frag trial**: in matched Full/Skills setups with readiness bridge and `bot_action_policy 1`, `bot_skill_use 1`, test `bot_frag_safety 0/1` with `bot_frag_input_probe 1`. Count bot frag self-deaths **and** enemy frag kills against qualifying bot life/round exposure, ordnance requests, actual projectile release/detonation if instrumented, player movement, self-splash and utility. Do not label script readiness or an input edge as a cast. Existing Full v20 played counts (103 self-deaths, 37 enemy frag deaths) are *context*, not a randomized baseline cell.
5. **Human Pulse Blade trial**: install v1.1.0 into isolated profile only, compare native refill/readiness to 1.0.0; test no Power Cell, Power Cell, spawn/loadout transition, mod disable, other six tacticals, actual ability effect/range/duration and unchanged bot weapon behavior. A neutral `*1.0` modifier is not sufficient proof until runtime verified.
6. **UI exploration, separate client profile**: PR #11 is a reference, not a deployable mod. Integrate against the *installed* client minimap only after confirming local RUI APIs and backing up. Validate marker alignment, HUD overlap, resolution changes, teardown and topology budget with screenshots. Do not install the research fragment as a mod.
7. **Rollback and smoke**: test flag-off recovery, backup DLL restore, mod disable/remove, respawn, lobby, cross-map and uninterrupted CURRENT progress. End with the isolated test profile in its previous known-good state unless BT-7274 explicitly authorizes promotion.

## Privacy, analysis and pass/fail

For local telemetry:

```powershell
node tools/Analyze-BotAITrial.mjs --baseline <baseline-log.txt> --trial <trial-log.txt> --out <private-comparison.json>
```

Use separate epochs and matched exposure. The analyzer returns aggregate log counts and code histograms; no actor handles, positions or raw logs. It **does not** infer kills, successful traversal, projectile events or causation. Raw logs, dumps, private saves, player identifiers and binary DLLs stay local; publish only reviewed derived aggregates, hashes, a reproducible trial matrix and specific code fixes.

**Stop/revert for** startup errors, crashes, incorrect core, bot count/aim/human modifiers, lost progress, blocked respawn/map return, stuck buttons, significantly worse map stalls, unintended frag harm, or clear p95 server-frame regressions. Record each failure, whether a test genuinely ran, exact commit and switch settings, and whether a rollback was confirmed. Never turn missing telemetry into a pass.

## Required local-agent output back to repository

Write `research/bot-ai/LOCAL-VALIDATION-YYYY-MM-DD.md` with build SHA, toolchain versions, commands, test counts/failures, isolated profile hashes, exact map/cohort matrix, observations separated from hypotheses, exceptions/blocked checks, confidence and decision for each switch. Keep the original commit and backup links; open PRs for fixes with evidence. **Do not promote to normal profile on the strength of source review alone.**

## Agent directive

> Check out the latest main of BigCatMellow/TitanFall2. Read AGENTS.md, docs/LOCAL-TEST-HANDOFF-2026-10-29.md, Notes/CURRENT-SETUP.md, and the latest handoff. Preserve installed profiles/CURRENT saves and all dirty local changes. Run Node/Rust offline tests and the pinned Windows DLL build; audit each failure before any install. Test only in map-cycle-test-profile with verified Northstar 1.31.14.0 and a full rollback snapshot. Treat every new switch as default-off, run measured one-variable-at-a-time A/B tests for target selection, route-corner height, repeated stalls, low clearance and frag safety across Eden/War Games/Complex/Meadow; separately validate Pulse Blade human recharge and the unimplemented minimap research. Record real gameplay outcomes and server-frame performance, not merely command/request counts. Publish sanitized results and follow-up PRs only, without overwriting normal installs or CURRENT saves. Report exactly what was and was not validated.
