# Bot capability candidate v20 — 2026-10-27

**Windows playtest installed October27.** Normal defaults to Movement; gated
geometry/perception switches stay off. See
[actual validation and presets](../../Notes/candidates/bot-capability-v20-20261027/README.md).
The original source design/protocol below is retained; statements about unrun
checks describe that earlier source stage, not the current rollout.

Seven new switches, all source defaults `0`. With every
switch at 0 the command path matches installed v19 (same inputs; the only extra
work is bookkeeping in per-bot structs). Nothing here was run in the game.
Aim `0.78`, the existing 0.8 s firing warm-up, weapon damage/RPM, team sizes,
saves, the two-buffer pathfinder, map teardown and target-sharing safeguards are
unchanged. Supersedes the *approach* of draft PR #5 (it does not reuse its
`bot_low_clearance_trial` switch, so both can be compared if wanted).

Why these changes: see the review findings summarized below. Code evidence is in
`bp_ort/src/bots/cmds/basic_combat.rs`, `cmds_utils.rs` and
`navmesh/navigation.rs`; data evidence is in
[played-weapons-20261026](../played-weapons-20261026/FINDINGS.md) and the Eden
mesh decode under `Notes/map-context/mp_eden_small`.

## Switches

| Switch | What it does | Inputs changed? |
|---|---|---|
| `bot_nav_diagnostics` | Logs `BOT_PATH` (raw status, partial bit, link count, end gap), `BOT_CORNER` (straight-path flag + native jump type per corner), `BOT_STALL` (on watchdog/waypoint recoveries: corner type, partial, **stand vs duck hull fit** toward the next point), `BOT_STUCK` (commanding movement, grounded, <30 u/s for 1.5 s in **any** state incl. engage), `BOT_CROUCH`, and one `BOT_VIEWCHECK` per bot per map (eye angles, raw `view_angles`, eye height, stand/duck hulls). Rate-limited. | No |
| `bot_route_guard` | A consumed *partial* route is not re-requested every frame (0.5 s throttle). A pursuit target whose routes stay partial and end >250 units short for 3 s is skipped **for pursuit only** for 6 s. Visible engagement is unaffected. | Yes |
| `bot_jump_timing` | Step jumps fire only within 140 units of a waypoint 18+ units higher (previously at any distance, e.g. 400 units early). One bounded second press (double jump) when airborne ≥0.2 s and the waypoint is still >40 units above. | Yes |
| `bot_proximity_fix` | Titan boarding `Use`/look-at and titan melee used `dx²·dy² < r²`, true whenever either axis is aligned at any distance (mid-fight aim snaps to own Titan). Uses `dx²+dy² < r²`. | Yes |
| `bot_perception_fix` | Facing from known eye angles (degrees) instead of dotting a direction with `view_angles`; keeps the **same 180° hemisphere** the old `cos(270°)=0` threshold produced. Sight line from eye to target upper body (the line shots already travel) instead of feet to feet+20. | Yes (who is "visible") |
| `bot_combat_movement` | Requires `bot_combat_decisions 1`. Out of range: follow the navmesh route toward a visible target while aiming (was: walk straight at it, ignoring geometry). In range: full-strength strafes with per-bot pseudo-random 0.4–1.2 s reversals (was ±0.3, fixed 3.2 s), ranked blocked-step alternatives, keep last grounded choice while airborne (was zero input). | Yes (movement only) |
| `bot_crouch_recovery` | Stall-triggered (grounded, commanding movement, <50 u/s for 0.4 s). Sweeps the player's **actual** `m_StandHullMin/Max` and `m_DuckHullMin/Max` (read from the player, plausibility-checked) toward the next route point with a player-collision mask incl. `PLAYER_CLIP`; bottom 18 units ignored for steps. Crouches only if stand is blocked and duck fits; releases once standing fits again; ≤3 s; fails on <8 units progress per 0.6 s; failed spots are skipped for 20 s (96-unit radius). Failure hands back to existing recovery. | Yes |

Weapon notebook (`Solo.WeaponNotes` 1.1.0) adds two opt-in convars, both default `0`:
`solo_weapon_notes_fire` (rounds spent per gun/mods/config from magazine decreases,
ADS share if `GetZoomFrac` exists, own error budget so it can never disable the
damage notebook) and `solo_weapon_notes_viewkick` (eye-angle drift per burst;
only meaningful in controlled no-input tests). The analyzer reports a
**observed-expenditure proxy** for matched actor/life/time/config windows.
It is neither accuracy nor a guaranteed lower bound; magazine polling can miss
rounds. Invalid denominators and over-unity windows produce no ratio.

`tools/Analyze-NavDiagnostics.mjs` summarizes the diagnostic lines and applies
the Experiment 1 decision rule (stall samples grouped into per-slot incidents).

## What PR #5 got wrong that this design avoids

- Shot-mask rays (`0x46404033`: no `PLAYER_CLIP`, includes hitboxes/bullet clip)
  measured what blocks bullets, not players. This uses hull sweeps with a
  player-collision mask.
- Guessed heights (64/36/8). This reads the engine's own stand/duck hulls.
- Probing every 0.2 s while sprinting meant a 48-unit displacement guard aborted
  most attempts at sprint/slide speed. This only triggers once the bot is
  already stalled, so momentum is not a factor.
- Failure handed off to jump/diagonal recovery under the ceiling and retried the
  same spot. This remembers failed spots and never adds jump while crouching.

## Original source-stage validation (historical)

- 15 Rust pure suites (99 tests; 5 new suites, 24 new tests) and 8 Node suites pass
  on Linux. `tests/weapon_roles.test.mjs` had a stale assertion on main (it
  required pre-integration wording); updated to the current documented status.
- `cargo check -p bp_ort` for `x86_64-pc-windows-gnu`: no new warnings or errors.
- Distribution DLL cross-built on Linux (stable 1.97 with `-Zbuild-std`, MinGW
  GCC 13): PE32+ x86-64, SHA256
  `e2bb7736712eef1944ea2d99b3b7c15bb1256e4d9a83cacbeb25eb4b14dc8f9e`. **Not the validated pinned nightly/LLVM-MinGW toolchain**;
  rebuild with `tools/Test-Project.ps1` + the README build command on Windows
  before any runtime test. Binary not committed.
- Squirrel changes are not compiled or run here. Missing script APIs fail only the
  opt-in sampler (separate error budget, defaults off).

## Not verified (runtime required)

1. `create_trace_hull` ray initialization (used only by OctBots so far) and the
   rrplug offsets of the hull fields. `BOT_VIEWCHECK plausible=1` and sensible
   `BOT_CROUCH`/`BOT_STALL` fits are the first gate; implausible values keep
   crouch recovery inert and log one warning.
2. Titanfall's Detour partial-result bit and the straight-path jump encoding.
   Read `BOT_PATH status=` and `BOT_CORNER` distributions before trusting
   `partial=`/link counts (`bot_route_guard` depends on the partial bit).
3. Whether `GetZoomFrac`/`EyeAngles` exist as called in the notebook sampler.
4. All gameplay outcomes. Nothing here is evidence that bots got better.

## Runtime protocol (isolated `map-cycle-test-profile` only)

Back up CURRENT deployment and saves; never restore old saves; verify Northstar
1.31.14 in the log and the startup label
`bot-capability-v20-candidate`. Startup and lobby return with all switches 0
first; confirm normal settings retained. Telemetry interval 0.5 only in the
isolated profile.

**Experiment 1 — what causes stalls (diagnostics only).** `bot_nav_diagnostics 1`,
everything else 0. Two rounds each on Eden, War Games, Drydock plus one control
map (Meadow). Also stand at Eden `setpos 4100 -350 80` (cheats in isolated profile
only) and screenshot both sides of the strip at x≈4085–4117.
Run `node tools/Analyze-NavDiagnostics.mjs --log <nslog>`.
- If `link_or_partial_share ≥ 0.5`: enable `bot_route_guard` + `bot_jump_timing`
  next; consider excluding the offending jump type in the human filter.
- If `duck_only_share ≥ 0.3`: proceed to the crouch trial below.
- Record `BOT_VIEWCHECK` once: settles what `view_angles` returns.

**Experiment 2 — combat movement.** ABAB by match, 4+ map pairs (include Eden,
War Games, Traffic, Meadow), `bot_combat_movement` 0 vs 1, diagnostics on in both.
Measure: share of range-hold samples <50 u/s (target <20%), `BOT_STUCK` by state,
damage-to-death span for human-killed bots (target ≥20% longer), human pilot K/D
per 10 min (target ≥25% lower), environmental/fall deaths (must not rise), blinded
fun/fairness rating (not worse). Aim and warm-up unchanged by construction.

**Experiment 3 — perception + proximity.** `bot_proximity_fix 1` alone first
(expect no Titan-aim snaps; compare `BOT_STUCK`/death context). Then
`bot_perception_fix` ABAB: engage-state stuck episodes should fall; human damage
taken per minute must not rise faster than human K/D falls.

**Crouch trial (only if Experiment 1 supports it).** `bot_crouch_recovery 1` with
diagnostics. Per identified obstacle/direction: 20 baseline vs 20 candidate
approaches; success = crossing a predeclared exit plane alive on the intended
floor and resuming the route. Accept ≥18/20 and ≥5 more successes than baseline
(or ≥25% faster median if baseline ≥18/20). Negative controls (wall, too-narrow
opening, ledge, doorway, stairs, airborne): zero crouch starts. Lifecycle:
respawn, loadout change, combat interruption, boarding, switch-off mid-passage,
map swap, lobby return — no stuck Duck. Server frame median/p95 within 10%.

**Weapons.** `solo_weapon_notes_fire 1` in normal play is read-only and can be
enabled after one isolated session shows no `WNOTE_FIRE_ERROR`. Then run blinded
per-match ON/OFF toggles of one weapon modifier at a time, 6–8 matches each
(Flatline ADS time and ADS recoil separately; Volt reload and recoil
separately). Revert if the change is not identified better than chance and the
controlled hit-rate measurement differs by <5 points (the expenditure proxy alone is insufficient); revise if it dominates its control
(R-201/CAR) in the same range band; keep only if perceptible, preferred, not
dominant. View-kick: `solo_weapon_notes_viewkick 1`, fixed position, no mouse
input, 10 bursts per condition.

## Rollback

Every behavior is a convar: set it to 0 (takes effect on the next command). Full
rollback: close the game, restore the pre-trial DLL from the CURRENT backup, keep
CURRENT saves, verify DLL/config hashes and startup/lobby return. The notebook
1.1.0 with both new convars at 0 behaves as 1.0.0.

Review correction: magazine polling now captures actor/life/time/config windows.
It reports `pilot_hits_per_observed_round` only for valid matched windows;
`pilot_hit_fraction` is null because an exact shot denominator is not proven.
This proxy is not accuracy or a guaranteed lower bound. Missing intervals,
reload ambiguity, invalid counts or over-unity results invalidate the ratio.
Sampler runtime/API validation is still required before using it in trials.
