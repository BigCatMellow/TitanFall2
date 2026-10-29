# Tactical cooldown audit and Pulse Blade trial — 2026-10-28

## Decision

The first balance candidate restores Pulse Blade to its unmodified refill rate while leaving the other six tactical recharge bonuses alone. This isolates the radar concern the player reported and keeps the current Power Cell behavior. It does **not** change Pulse Blade range, bot skill policy, aim, damage, or other tactical settings.

This is source for an isolated trial only. It has not been installed or run in Northstar. The normal profile and saved loadouts remain unchanged. The current main-branch add-on is still version 1.0.0, which accelerates all seven human tacticals.

## Two separate systems

`BT7274.TacticalRecharge` applies only to the local human in the insecure solo profile. Its named modifiers are not applied to bots, Titans, or ordnance.

Bot tactical decisions are separate. In the v20 Full trial, bots may request Pulse Blade when a target is unseen and 300–1,500 units away. Requests pass through fresh engine-readiness checks, a 0.12-second input pulse, and a one-second local throttle. The bot code does not set tactical refill rates. Grapple remains unhandled because it needs movement and safe-landing logic.

The Full-session report counted 4,023 allowed input starts (1,727 tactical, 2,296 ordnance), including 810 Pulse-reveal reasons. These are requests, not confirmed casts. Shot counters stayed zero; resource samples below the use threshold suggest some consumption but do not prove when an ability activated or whether it helped. Do not use request frequency as a bot cooldown measurement.

## What the existing human modifier changes

Version 1.0.0 multiplies tactical `regen_ammo_refill_rate` by 2 and `regen_ammo_refill_start_delay` by 0.5 for all seven abilities. The archived isolated runtime test read these rates with Power Cell equipped. Northstar documents refill rate as ammo units per second and the start delay as the wait after a shot before refill begins. A faster rate does not imply the same absolute cooldown or combat uptime for every tactical: charge cost, charge count, start delay, active duration, and whether recharge overlaps an active effect all matter.

| Tactical | Archived runtime readback with Power Cell, before → v1.0.0 | What to measure next |
|---|---:|---|
| Grapple | Empty-to-full stopwatch: 24.7 s → 12.4 s | Full charge interval, useful movement gained, and whether shorter recovery changes route choice. This is a test-condition result, not a universal Grapple cooldown. |
| Cloak | 13.5 → 27 ammo/s | Actual active time and the fraction of a match spent cloaked. Check whether recharge finishes before the active effect ends. |
| Stim | 10.8 → 21.6 ammo/s | Successful chase/escape activations, active time, and survival or health recovery after use. |
| Holo Pilot | 10.8 → 21.6 ammo/s | Charge use and decoy outcomes; separate two-charge behavior from cooldown. |
| Phase Shift | 18 → 36 ammo/s | Confirm activations first, then record actual escape outcomes and recharge overlap. |
| Pulse Blade | 10.8 → 21.6 ammo/s | Time from throw to ready, scan uptime, and whether each scan reveals a useful target. The player reports that the current radar availability feels nearly continuous. |
| A-Wall | 6.75 → 13.5 ammo/s | Confirm placement/activation, time the wall’s useful coverage, and record whether it changes damage taken/dealt. |

The six weapon-rate pairs and Grapple stopwatch are from the repository’s archived 2026-10-24 isolated test. They are historical validation, not a test of this candidate. The rates are not cooldown seconds. A-Wall and Phase have no confirmed bot cast in the played Full telemetry, so there is not enough evidence to shorten or lengthen their cooldowns yet.

## Candidate change

The candidate changes only `mp_weapon_grenade_sonar.txt`:

```text
regen_ammo_refill_rate "*1.0"
regen_ammo_refill_start_delay "*1.0"
```

That returns Pulse Blade to its normal weapon refill behavior when the named mod is present; the separate Power Cell modifier is preserved. The other six tacticals retain `*2.0` rate and `*0.5` delay. The Squirrel startup line reports Pulse as `profile=native` and the other six as `profile=half`, so it no longer labels the Pulse multiplier as a half-time profile.

Cooldown is the first lever because it is a small KeyValues-only change. Do not tune range in the same trial. A community mirror of the game scripts contains `SONAR_GRENADE_RADIUS = 1250` and a six-second pulse constant, while the Pulse Blade reference describes a 4.5-second pulse. Treat those figures as build-dependent until the installed runtime is read back. Range tuning would need a separate script/runtime override and a separate test.

## Per-skill balance method

Evaluate each tactical by confirmed activations and effect uptime, not by button requests or raw cooldown alone. For each one, record:

- Equipped tactical, Power Cell state, and exact mod/profile.
- Activation timestamps, time until ready, charge count, and active-effect start/end.
- Useful outcomes: revealed enemy encounters, successful disengages, health recovered, decoy reactions, protected firing time, or movement to a reachable route point.
- Ability uptime per match and the player's fairness/usefulness rating.

Tune one tactical at a time. First establish whether it activates as intended, then compare its actual useful uptime against its effect and risk. Keep Titan abilities and ordnance in separate reviews.

For bots, add explicit activation/deactivation or successful-use telemetry before setting per-skill cooldowns. Current `BOT_SKILL` reason counts and readiness snapshots do not distinguish an issued input from a successful tactical cast. Preserve the existing readiness gate while that evidence is collected.

## A/B trial

Use the isolated `map-cycle-test-profile`; do not replace the normal-profile mod or restore historical saves.

1. Run a matched baseline with v1.0.0 and a trial with this candidate. Keep map, bot preset, roster, loadout, weapon, Power Cell, match length, and all other settings fixed. Use the same Power Cell state in both runs.
2. On each run, record Pulse Blade throw/use time, ready time, observed scan start/end, and any actionable reveal. Also record match duration and a 1–5 usefulness/fairness rating.
3. Compare the actual throw-to-ready interval and share of time with an active scan. Repeat the pair on the same map before deciding whether stock recharge is enough.
4. If Pulse becomes too weak at stock recharge, test one intermediate refill multiplier in a separate candidate. Only test range after the cooldown result is clear.
5. Recheck the six other tacticals individually with the same timing/outcome fields; do not copy the Pulse setting across them.

The historical v1.0.0 isolated harness verified six tactical refill multipliers, unchanged duration/ammo, the start-delay modifier, non-stacking, disable/restore, and no bot modifier. Grapple was separately timed. This v1.1.0 candidate still requires the same isolated runtime checks, including Power Cell on/off, Pulse readiness, unchanged active effect/range/cost/charge count, disable/restore, respawn/loadout changes, and bot exclusion.

## References

- [Repository's tactical recharge implementation](../../BT7274.TacticalRecharge/README.md) and [archived test notes](../../Notes/TACTICAL-RECHARGE.md).
- [Northstar weapon KeyValues](https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/) defines refill rate and refill-start delay.
- [Pulse Blade reference](https://titanfall.wiki.gg/wiki/Pulse_Blade) reports a 25-second recharge and 4.5-second pulse.
- [Community Titanfall 2 script mirror](https://github.com/Syampuuh/Titanfall2/blob/master/scripts/vscripts/sh_consts.gnut) reports sonar radius/duration constants. It is not a substitute for the installed game/runtime readback, and its duration value differs from the Pulse Blade reference.
