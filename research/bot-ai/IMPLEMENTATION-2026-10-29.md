# Bot AI improvement pass 1 — 2026-10-29

This is the first **source-only**, **default-off** experiment after the bot-AI architecture research. It does **not** install a DLL, modify Northstar, change player saves, or imply gameplay validation.

Rollback snapshot: [backup/pre-bot-ai-20261029](https://github.com/BigCatMellow/TitanFall2/tree/backup/pre-bot-ai-20261029), pinned at `1b223ee62e5ebad23f4c35954601313e579ef64d`. Work branch: `experiment/bot-ai-first-pass-20261029`. Neither unrelated open PR #9 (corner-height guard) nor PR #10 (human Pulse Blade recharge) is modified.

## Why these two isolated trials

The [Full v20 review](../played-full-v20-20261027/FINDINGS.md) recorded 103 bot-pilot frag self-kills and 37 opposing pilot frag kills; it also recorded Eden low-progress windows and link/partial-route classifications. Counts are from a specific played session, not a randomized controlled trial.

1. **`bot_nearest_pursuit 1`** switches only the *uncoordinated*, *no-visible-target* fallback from choosing the **farthest** candidate (the existing `reduce` condition) to the **nearest** candidate. It does not change visible-enemy selection, the team coordination ranking, aiming or attack rules. The existing farthest-first behavior remains when off. The similarly named `closest_player` helper is a separate cleanup candidate and is not altered here.
2. **`bot_frag_safety 1`** applies only when `bot_skill_use 1` is already enabled: bot frag requests require a visible target, `range_hold`-style intent, no pursuit/advance, at least 70 health, 700–1100 units horizontal range, and height difference at most 120 units. Frag request starts are spaced **6 seconds** apart rather than 1 second, while each valid press keeps the previous 0.12-second maximum pulse and readiness gating. All other ordnance and all tactical abilities keep their existing logic.

All switches default to **0**, preserving existing normal/Full commands until an explicit isolated trial. Existing aim error `0.78`, firing warm-up `0.8s`, damage, RPM, human reload/recharge, bot count, two-buffer navigation, map teardown, and lifecycle safeguards remain unchanged.

**Limitations:** The frag guard is intentionally conservative but cannot prove a safe throw. It has no projectile trajectory, wall clearance, owner-to-grenade distance, fuse or post-release escape signal. It might reduce both self-kills **and** useful enemy kills by throwing less. Do not enable it as a default until measured. The nearest fallback may choose an unreachable nearby player and is not intended to replace route-guard recovery or typed traversal links.

3. **`bot_stall_target_recovery 1`** is an independent, default-off response to the Eden full-route stalls not covered by the existing partial-route guard. After two actual watchdog recoveries for the same pursuing bot and target within 12 seconds, that bot avoids selecting the target for the next 8 seconds *if another candidate exists*. Visible enemy engagement is never suppressed. Both coordinated and uncoordinated pursuit selection honor the cooldown; one-opponent cases fail open. No navmesh or movement physics are modified.

## Source and verification

- `bp_ort/src/bots/target_policy.rs`: pure distance-selection logic and two unit tests.
- `bp_ort/src/bots/skill_policy.rs`: frag eligibility with negative controls.
- `bp_ort/src/bots/action_policy.rs`: configurable inter-start interval while retaining readiness, release and weapon/reset semantics.
- `bp_ort/src/bots/cmds/basic_combat.rs`: opt-in wiring.
- `bp_ort/src/bots/mod.rs`: default-off convars and per-life reset of the new stall state.
- `bp_ort/src/bots/route_guard.rs` and `cmds_utils.rs`: repeated-stall memory and watchdog integration.
- `bp_ort/src/bots/frag_input_probe.rs`: default-off command edge diagnostic, isolated tests, and reset on lifecycle/switch-off. The log deliberately says **input** rather than throw/cast. Five test cases in the two pure-policy modules cover targeting and route recovery.

Before game deployment, run `tools/Test-Project.ps1` and `cargo +nightly-2025-09-11-x86_64-pc-windows-gnu test -p bp_ort --locked` with the pinned Windows toolchain and compile a distribution DLL as in the root README. Test both convars off for exact current behavior, then one switch at a time, then their combinations. The code was edited remotely; no local Rust toolchain or installed game was available in the editing environment. **No native compile, Rust test, DLL install or Titanfall runtime test is claimed by this pass.**

## Isolated A/B gate

The third switch is tested as a **separate navigation A/B** before any combined test: with `bot_nearest_pursuit 0`, compare `bot_stall_target_recovery 0/1` across matched Eden, War Games and Meadow rounds with the same loadouts and goals. Record `BOT_ROUTE_COOLDOWN` events, target reacquisition, median time to first engagement, partial/full routes, route failures, low-progress windows and target churn. Negative controls: near-visible enemy attacks must never be blocked, no stale blacklist across respawn/map/lobby, and the sole available target remains eligible. The diagnostic logs identify decisions, **not** that a route became traversable. Reject for more idle time, new no-target loops, or regression in played-fight fairness.


Use the existing **map-cycle-test-profile**, never overwrite the normal profile or CURRENT saves. Verify core `1.31.14.0`, native hash, 8v8, aim `0.78`, unchanged warm-up and known baseline. Run matched Eden, War Games, Complex and Meadow rounds using independent switches:

| Cell | `bot_nearest_pursuit` | `bot_frag_safety` | Measure |
|---|---:|---:|---|
| A — baseline | 0 | 0 | current target choices, stalls, frag events |
| B — targeting | 1 | 0 | target switches, chosen distance, partial paths, stall episodes, engagement time |
| C — frag | 0 | 1 | allowed ordnance starts, frag self-deaths, opposing frag deaths and health losses |
| D — combined | 1 | 1 | interaction and regression checks |

Enable `bot_frag_input_probe 1` during the **isolated frag A/B** only. It emits `BOT_FRAG_INPUT` with `edge=press/release`, input hold time, bot location, movement speed, target/visible state and last script readiness value/age. Pair those with private `BOT_READY`, damage and death logs to locate suspicious timing. **Command release is not projectile release**, readiness is not a cast, and the log has no verified grenade path, collision, fuse, or owner-distance outcome. Never claim causality from matching timestamps alone.

The baseline Full played cohort is context, not an A cell from this new test. Collect new matched baselines with the same player, maps, loadouts and round goals; keep played and unattended sessions separate. For frag, report **both** self-kills per qualifying bot-life/round and enemy frag kills, as well as total requests: a reduction in total throws alone is not proof of better skill. Inspect owner, projectile release, close-wall collisions, and post-throw bot paths before accepting a guard. For targeting, compare route completion and stuck incidents without assuming nearest is reachable. Reject if map-cycle, respawn, inventory change, Titan transitions or lobby return retains stuck input.

Stop and revert immediately for startup/server errors, increased environmental deaths, worse p95 server-frame times, unbounded target churn, or clear regressions in combat utility. Feature rollback: set the two convars to `0`. Full native rollback: restore the verified pretrial DLL backup, **retain CURRENT saves**, and confirm startup/map/lobby transitions. Do not modify normal installed settings from this PR.

## Architecture decision

No full rewrite is protected by policy: BT-7274 has authorized replacing the bot stack if evidence justifies it, provided the working state is backed up. Prefer a **hybrid** design for further work: native Detour for ground paths, explicit traversal-edge actions (jump/crouch/wall-run/grapple), OctBots behavior trees for sequencing, utility-scored tactical choice, bounded perception memory and local avoidance. Do **not** merge the two simulation loops directly or introduce a third runtime controller without performance and map-lifecycle tests.

Next independent passes: instrument frag lifecycle and collision/escape; verify Phase/A-Wall casts; prototype a typed Eden traversal link and failure recovery; then add perception memory/hysteresis and weapon/ability profiles. Use dedicated opt-in trials and preserve attribution to [catornot/bp-ort](https://github.com/catornot/bp-ort), [Recast/Detour](https://github.com/recastnavigation/recastnavigation) and [Northstar](https://github.com/R2Northstar/NorthstarMods). The separate deep-research artifact is not represented as already committed.
