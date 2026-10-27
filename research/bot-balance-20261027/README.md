# Solo balance plan and candidate — 2026-10-27

**Goal agreed with BT-7274: about 3:1 human pilot K/D** (band 2.5–3.5) in normal
8v8 solo play. Allowed levers: bot movement/decisions, a bot loadout mix and bot
defensive tacticals. Not used: aim (stays 0.78), the 0.8 s firing warm-up,
damage/RPM, team sizes, and the human's own buffs (recharge, reload, ADS/role
trials stay as installed).

## Baseline (published v19 played session, 2026-10-26)

`node tools/Check-BalanceTarget.mjs research/played-weapons-20261026/analysis.json`

| Map | Human pilot K/D | Kills/10 min |
|---|---:|---:|
| Eden | 7.0 (14/2) | 26.2 |
| Meadow | 16/1 (too few deaths) | 35.8 |
| Traffic | 24/0 (too few deaths) | 46.8 |
| War Games | 5.5 (33/6) | 29.5 |
| **All** | **9.7 (87/9)** | — |

Median damage-to-death of bots you killed (clean episodes): 0.33 s, about the
theoretical minimum for those guns, i.e. bots are not evading. On Eden/Meadow
59–81% of bot views of you had a vertical gap over 180 units. Bots carried the
R-201 in >99% of samples and never used a tactical.

## Levers (all default off)

| Switch | Source | What it changes |
|---|---|---|
| `bot_combat_movement 1` (+ `bot_proximity_fix 1`) | PR #6 | Route toward visible targets, full randomized strafes, blocked-step alternatives |
| `bot_height_response 1` | this PR | Enemy 180+ units above and visible for 1 s → move to a nearby navmesh point it cannot see (≤6 candidates, same floor, 100–600 units), hold 4 s, 10 s cooldown. Still aims/fires when it sees you |
| `bt7274_bot_roster 1` | `BT7274.BotRoster` | Same 8-gun list per team by rank: R-201, G2, CAR, Flatline, DMR, Spitfire, Hemlok, R-97 (stock). No one-shot, splash or heat guns |
| `bt7274_bot_tacticals 1` + `bot_defensive_tactics 1` | add-on + this PR | Stim on 3 of 8 ranks, Phase on 2; Stim/Phase fire whenever health <60 (readiness-gated; needs `bot_action_policy 1`, already on) |

Requires the v20 native candidate (PR #6) underneath; this branch is stacked on
the rename (PR #7), so add-on names use the BT7274 prefix.

## Procedure (isolated profile first, then normal play)

1. **Baseline:** current setup + `solo_weapon_notes_fire 1`; 2 matches each on
   Eden, Meadow, Traffic, War Games. Run the played-session analyzer, then
   `Check-BalanceTarget.mjs`. (Traffic/Meadow need ≥2 deaths to judge.)
2. **Add one lever per step**, same 4 maps × 2 matches, comparing with
   `--label baseline … --label step2 …`:
   1. combat movement + proximity fix
   2. height response
   3. bot roster
   4. tacticals + defensive tactics
3. **Stop** as soon as the pooled K/D is within 2.5–3.5. If a step overshoots
   (<2.5), turn that lever off or keep it on only for the enemy-heavy step
   below it; never compensate with aim.
4. **Also check** every step: environmental/fall deaths not rising,
   `BOT_ROSTER_ERROR` absent, `BOT_COVER found=1` share, no stuck crouch/Duck,
   and your 1–5 fun/fairness rating (must not fall — "harder" must not feel
   cheap).

Expected direction, not a promise: movement should lengthen the 0.33 s bot
damage-to-death; height response should cut the free kills from above
(Meadow/Eden); the roster adds threat at the 1,000–1,500-unit ranges you
fight at; Stim/Phase add escapes. Weapon-role questions about your own guns
(Volt recoil etc.) come after the K/D is in band.

## Validation done (offline only)

Pure Rust tests incl. 5 new height-response and 1 defensive-tactics test; balance
checker tests; Windows-target `cargo check` clean. Squirrel add-on not compiled
or run here: it reuses the loadout calls the isolated weapon matrix already
exercised, plus `GetOffhandWeapon(1)` / `GetPlayerArrayOfTeam`, which are
unverified. Errors stop the add-on after 3 and are logged.

## Rollback

Every lever is a convar → 0 (roster/tacticals apply at the next respawn).
Disable `BT7274.BotRoster` in enabledmods.json for full removal; keep CURRENT saves.
