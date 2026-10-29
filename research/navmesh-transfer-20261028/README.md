# Navigation follower lessons and an isolated Titanfall 2 trial

Integration update: this preserves the original research proposal. The narrower
Windows candidate and current test/build protocol are in
[v22 isolated trial](../corner-height-v22-20261028/README.md). It excludes all
start/end/traversal markers, downward corners and Titans. Use release-debug
with the original lockfile and offline pinned dependencies; the original build
commands and unbuilt status below describe this branch before integration.

Date: 2026-10-28

## Additional remote review

Date: 2026-10-28  
Repository base reviewed: [1b223ee](https://github.com/BigCatMellow/TitanFall2/commit/1b223ee62e5ebad23f4c35954601313e579ef64d)

This note turns proven ideas from related navigation systems into a small, reversible experiment for the Northstar bot follower. The code change is a candidate only: the new switch defaults to off and has not been built, installed, or tested in a game.

## What the project already knows

The current native follower stores Recast straight-path corner flags and a second traversal byte in `Navigation::corner_meta`. `path_to_target` logs those values when `bot_nav_diagnostics` is on, but it does not select an action from the raw traversal byte. Jump input is currently selected from waypoint height and distance.

The corner-consumption check calls `distance()`, which is XY-only, and pops a corner once the bot is within 45 horizontal units. A bot on a lower floor can therefore be horizontally near a waypoint on a higher floor and consume it before reaching its height. This is a concrete code path to test, not proof that it caused the recorded stalls.

The goal search uses `TARGET_EXTENTS = (200, 200, 500)`. The native route diagnostics already record route status and projected endpoint gap. Northstar's own API documentation warns that overly large clamp extents can return a point far from the requested point, and exposes hull-based clamping and a graph-reachability query. That makes endpoint distance and reachability useful follow-up diagnostics; it does not establish that broad extents caused this project's stalls.

Relevant local code at the reviewed base:

- [Navigation data and target extents](https://github.com/BigCatMellow/TitanFall2/blob/1b223ee62e5ebad23f4c35954601313e579ef64d/bp_ort/src/navmesh/navigation.rs)
- [Route following and XY-only distance](https://github.com/BigCatMellow/TitanFall2/blob/1b223ee62e5ebad23f4c35954601313e579ef64d/bp_ort/src/bots/cmds_utils.rs)
- [Jump and route guard helpers](https://github.com/BigCatMellow/TitanFall2/blob/1b223ee62e5ebad23f4c35954601313e579ef64d/bp_ort/src/bots/route_guard.rs)

## Lessons from related systems

| System | What its authors built | Transfer to this project |
|---|---|---|
| Titanfall/Apex navmesh tooling by Kawe Dev | Connects separated polygon islands with typed traversal links. Link eligibility uses a traversal-type mask; geometry line-of-sight/collision validation rejects links blocked by world geometry. The runtime then filters links for the actor's capabilities. | Treat a traversal marker as an action contract, not merely as a height hint. First establish the Titanfall runtime byte encoding and hull meaning from route logs; only then map particular values to jump, drop, climb, or unsupported actions. |
| Northstar NPC navigation API | Offers AI/hull-specific point clamping, clamp-with-extents, nearby graph positions, and an explicit reachability query. Its docs warn that very large extents can snap to a distant point. | Record requested target, projected route endpoint, 3D endpoint gap, hull, and reachability before changing the 200x200x500 search extents. Compare a tighter hull-specific search in isolation. |
| Valve Source NextBot PathFollower | Does not advance past every nearby corner. Its follower considers height and whether the next segment is directly traversable; its path optimizer refuses shortcuts across a potential gap or a non-ground/precise segment. | Keep corner advancement tied to both geometry and movement feasibility. The candidate here adds only a vertical-distance guard; Titanfall code has no verified equivalent of Source's `IsPotentiallyTraversable` / `HasPotentialGap` callbacks, so it does not claim full parity. |
| NorthstarNavs map work | Uses per-map, per-hull cleanup such as removing roofs, out-of-bounds regions, and pilot-only spaces from Titan meshes. Its public notes call out Eden roofs and a possible War Games skip issue. | Keep map/hull evidence separate. A follower fix cannot make an invalid mesh correct; compare known problem maps and control maps before deciding whether to change the follower or the mesh. |

No third-party source code or game navmesh binaries are copied into this candidate. The implementation adapts the high-level safety principle and adds project-native, opt-in Rust code.

## Current evidence and map selection

The first played Full v20 review recorded repeated low-progress windows on Eden (8.90% and 7.79% of live pilot samples in its two rounds), against 0.82% on Complex and 0% on Meadow. In the played-window navigation diagnostics, 238 of 429 grouped incidents (55.5%) had a link/jump-corner classification or partial route; the classification is provisional because the engine byte encoding and physical cause still need validation. These are observations, not independent failure counts or causal proof. See [the Full v20 report](../played-full-v20-20261027/FINDINGS.md).

Keep the older v18 unattended map cohort separate. It found 7.01% low-progress samples on War Games and 4.97% on Eden, making War Games an important non-Eden comparison. The cohorts used different builds, presets, maps, and session conditions; do not combine their rates. See [the v18 map findings](../maps-v18-20261026/FINDINGS.md).

The first A/B set should include:

- **War Games** and **Eden** as repeated route-problem maps.
- **Complex** and **Meadow** as lower-stall comparison maps.

This keeps Eden from becoming the only test case and checks whether a local corner rule creates regressions on routes that already behave better.

## Candidate in this branch

A new server convar, `bot_corner_height_guard`, defaults to `0`. At `0`, corner consumption follows the current XY-only behavior. At `1`, the follower consumes a corner only when it is within the existing 45-unit XY radius **and** within 36 vertical units. The 36-unit threshold is provisional, chosen as half the approximately 72-unit standing hull observed in the v20 diagnostics. It must be calibrated against actual route traces before any default change.

When `bot_nav_diagnostics 1` is enabled, a held close corner produces one `BOT_CORNER_HOLD` line per bot per second with the raw corner flags/jump byte, XY distance, vertical delta, waypoint and bot origin. This gives the trial a visible signal without assigning unverified meanings to the byte.

The candidate intentionally does **not**:

- infer traversal actions from raw corner bytes;
- increase global jump frequency or enable crouch recovery;
- change navmesh files, target extents, aim, damage, weapons, bot count, or normal-profile settings;
- enable route throttling or unreachable-target filtering.

## How to try it

Use a separate candidate build and the existing isolated `map-cycle-test-profile`. Do not replace the normal installed DLL for this trial.

1. From the repository root in PowerShell, run the project checks and build with the pinned toolchain, retaining debug symbols:

       $env:RUSTUP_TOOLCHAIN='nightly-2025-09-11-x86_64-pc-windows-gnu'
       $env:CARGO_PROFILE_DISTRIBUTION_STRIP='none'
       $env:CARGO_PROFILE_DISTRIBUTION_DEBUG='2'
       ./tools/Test-Project.ps1
       cargo +nightly-2025-09-11-x86_64-pc-windows-gnu build -p bp_ort --profile distribution --locked -j 1

   The DLL output is `target/x86_64-pc-windows-gnu/distribution/bp_ort.dll`. Stage that build only in the isolated profile, keeping its matching Northstar 1.31.14 runtime; preserve the current isolated DLL and configuration for rollback.
2. Start the isolated profile on the existing Movement preset, confirm the matching Northstar 1.31.14 core and candidate DLL hash, and leave the current 8v8 population/aim settings unchanged.
3. Keep `bot_route_guard 0`, `bot_jump_timing 0`, and `bot_crouch_recovery 0`. Enable `bot_nav_diagnostics 1`.
4. Run a baseline with `bot_corner_height_guard 0`, then a matched run with `bot_corner_height_guard 1`. Use the same map, goal/time cap, roster, and other settings for each pair. A 75-point team goal with the existing 15-minute cap keeps sessions bounded.
5. Repeat on War Games, Eden, Complex, and Meadow. Capture the ordinary server log and keep each map/build/preset as a separate cohort.

Compare per-map:

- low-progress pilot samples per 1,000 live pilot samples (and the original sample denominators);
- `BOT_CORNER_HOLD` frequency and whether the bot subsequently moves above/below the waypoint;
- partial-route status and projected-endpoint gap;
- sustained stuck episodes, route timeouts, runtime errors, and bot population.

A promising result is fewer low-progress/stuck windows on War Games and/or Eden, no new stuck loops on Complex or Meadow, and no route/runtime errors. A rise in hold messages without subsequent vertical progress means this particular gate is too strict or the mesh/transition needs a different solution. Do not interpret kill/death ratios or a single match as navigation proof.

Before deploying outside the isolated profile, run the project checks, build the native candidate on Windows, and complete the project's isolated movement/combat, population, map-transition, save, rollback, and error checks. This PR has not completed those gates.

## External references

- Kawe Dev, [NavMesh Traverse Links](https://www.kawe-dev.com/navmesh-traverse-links) — typed traversal masks, geometry checks, hull/actor capability filtering. Accessed 2026-10-28.
- Northstar, [NPC native server API: navmesh functions](https://docs.northstar.tf/Modding/reference/respawn/native_server/npc/) — clamp extents warning, hull-specific clamping, graph neighbors, and reachability. Accessed 2026-10-28.
- ValveSoftware, [Source SDK 2013 PathFollower::IsAtGoal](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/Path/NextBotPathFollow.cpp) and [Path::FindNextOccludedNode](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/Path/NextBotPath.cpp) — vertical-aware goal handling and safe shortcut checks. Accessed 2026-10-28.
- R2Northstar, [NorthstarNavs README](https://github.com/R2Northstar/NorthstarNavs#readme) — map/hull-specific navmesh cleanup notes, including Eden and War Games. Accessed 2026-10-28.
