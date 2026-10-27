# Combat decisions v16 — 2026-10-24

Status: deployed as a reversible solo trial after standalone and isolated
runtime checks. No claim of improved win rate or universally better AI.

DLL SHA256: C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075
Source snapshot: source-snapshots/v16-combat-decisions-20261024.zip
ZIP SHA256: ED2D282AEDEC3BA8F3EBC49F19972EC7DFFFDFFCB996BEAB98CF97D697CB40C9
Tracked diff beside the archive includes existing changes; untracked modules,
tests and script add-ons are included in the source archive. Do not reset
this checkout to upstream.

## What changed

New bot_combat_decisions convar defaults to 0, enabled as 1 in solo and isolated cfg.
It applies only to live legacy mode 6 pilots. Setting 0 restores v15 combat
controls immediately. Aim error, reaction delay, team count, weapon damage,
Titan combat, existing coordination and route/pathfinding logic are preserved.
Native navigation, path buffer bounds, detours, coordination and v15 escape
recovery files hash-match the complete pre-change source backup.

- Visible fights use weapon-specific distance bands and a 100-unit hysteresis
  margin so a bot does not oscillate between advance/hold near the boundary.
  Shotguns close to 300 units; SMGs 650; rifles 1000; precision weapons 1350;
  grenadiers 850; L-STAR 900. Inside the band, modest staggered lateral movement
  replaces constant forward charging. Outside it, legacy advance continues.
- If too close, or reloading near an enemy, a retreat is limited to 0.6 seconds
  per close-range episode. Further retreat requires separation/contact change.
  New side/back steps require grounded status plus wall and ground traces
 64 units ahead, cached for 0.2 seconds unless direction changes. This is a
  point trace, not a complete hull/navigation/cover planner.
- Known magazine-fed weapons explicitly request reload when empty. Low-ammo
  top-ups require 1.25 seconds without a visible threat and at most one-third
  of the largest observed clip for the current weapon. Reload requests are
  throttled 0.75 seconds. Reloading suppresses attack/ADS/melee/offhand inputs
  to help it complete. Heat/unknown/anti-Titan weapons are excluded from the
  new reload rules. Current attachments/magazines are not altered.
- Pilot melee uses dx²+dy² with a 90-unit horizontal radius and 55-unit height
  limit. The old product-of-squared-distances treated far-away axis-aligned
  enemies as close. Titan melee retains its existing behavior.
- Combat state clears on death, hull change and map reset. New BOT_COMBAT
  records include weapon, clip, reload flag, tactic and bounded-step counters.

Core files: bots/combat_decisions.rs (pure decisions), cmds/basic_combat.rs
(native integration and step checks), bots/mod.rs (state/convar), cmds/mod.rs
(lifecycle resets), cmds_exec.rs (telemetry), lib.rs (build identity).
No new native API, offset, memory layout or DLL dependency was introduced;
existing rrplug CWeaponX ammo/reload fields and trace functions are reused.

## Verification

All 33 standalone regression tests pass (20 existing + 13 new), distribution
build succeeds with embedded debug info, git diff --check passes. Existing
shared unused-import warning remains; standalone tests also report fields
only read by the native integration as unused. No compiler errors remain.

Isolated log: map-cycle-test-profile/logs/nslog2026-10-24 23-10-17.txt.
8v8, aim 0.78, Eden then Wargames, 30 total bot joins and 15 occupied bot slots
on each map. Eden ran 40 seconds with the new flag off, then enabled it live;
Wargames started enabled. The forced empty R-201 and EVA-8 magazines refilled
successfully. Normal advance, range holds, bounded retreat requests, actual
sideways movement commands and reload states were observed. Rifle, shotgun
and G2 cases ran. 34 alive Titan position samples occurred. Map teardown
released 15 navigation queries and the next map populated normally.
No script/compile errors, access violations, error-level logs or panics.

| Enabled pilot snapshots | Eden | Wargames |
|---|---:|---:|
| Total | 366 | 882 |
| Range hold | 31 | 33 |
| Range retreat | 3 | 2 |
| Reload / reload hold | 45 | 38 |
| Native reload flag set | 44 | 36 |
| Speed above 100 units/sec | 206 | 647 |

These are two-second samples, not counts of complete actions. State/counters
reset at death. A deliberate range hold can have low speed and is not itself
proof of navigation failure. The short encounters, changing weapon mix,
random spawns and largely idle human do not establish causal improvements
in performance, difficulty or enjoyment. Exact kills/accuracy are not logged.
Wargames used test-only forced shotgun/G2 spawns to exercise weapon ranges;
those overrides were not copied to the real profile.

Reports: sessions/combat-nslog2026-10-24_23-10-17/combat-summary.json and
combat.csv via tools/Export-CombatDecisions.ps1. General movement report and
replay use sessions/nslog2026-10-24_23-10-17 via Export-BotSession.ps1.
The test harness is archived in tests/combat-decisions-v16. The original
BT7274.BotCycleTest harness was restored after testing.

Everyday launch: nslog2026-10-24 23-16-24.txt, build v16. At 23:17:12 restored
902 fields and applied player recharge/reload modifiers; UI cache mismatch 0.
Actual aim 0.78 and combat decision states observed. User changed loadout
normally during handoff. No synthetic test save or forced bot weapons copied.
The real save hash matched the pre-change backup immediately before launch.

## Backup and rollback

Complete pre-change source, both original v15 DLLs/configs/saves, launcher
and test harness: backups/before-combat-decisions-20261024-230020.
Original v15 hash: 2A68A1CE0C0AB6294DE62C7E2742BE064C7ED086111C8251F1822FCCD22FA66C.

Fast toggle: server console bot_combat_decisions 0 (put spaces between name
and value: `bot_combat_decisions 0`). To persist, change the solo autoexec's
setting to 0. This retains v16 telemetry and all v15 safety/lifecycle fixes.
Full rollback: close Northstar and run Restore-Before-Combat.cmd. It verifies
and restores the solo v15 DLL/config, preserving current save files and
BT7274.LocalPersistence 1.2.1, TacticalRecharge and WeaponReload. It does not
replace the working source checkout. Regular Program Files remains v12.

Final normal-profile check: all16 occupied player slots sampled; new
BOT_COMBAT decisions active and no script/compile/access-violation/panic/error
entries at handoff. The current native DLL matches the tested candidate.
General replay export completed: Eden15 and Wargames18 pursuit/recovery
stall samples across763/1164 total bot observations. These remain navigation
limitations and are not a causal comparison with the previous build.
