# Weapon integration — October26

Integrated the user's four remote branches, preserving their commits:
weapon-mapping correction fd63b9c, ADS trial d5ec903, thirty-weapon research
da76335 and four-gun role trial d569e4c. The README merge retained completed
map-survey history and the Alternator/Volt correction.

## Installed behavior

| Scope | Change |
|---|---|
| Human Flatline |20% lower ADS recoil scales;25% shorter ADS-in/out fields|
| Human Volt |25% lower ADS recoil scales; preserve existing10% reload reduction|
| Human R-97 |30% lower hipfire spread accumulation and cap, standing/crouched/airborne|
| Human Spitfire |20% lower movement multiplier while ADS|
| Human G2 |25% shorter ADS-in/out; preserve existing reload reduction|
| Human Alternator |Correct classname; now receives the intended10% reload reduction|
| Native bot profiles |Added Alternator, Mastiff, Devotion, B3Wingman and P2016 to existing range/reload policy groups|

Damage, RPM, magazine values, bot aim0.78, human tactical recharge0.5 and normal
human+15bot8v8 remain preserved. Role balance is human-only; bot opt-in stays0.
Source add-on defaults remain opt-in/off, while the normal profile explicitly
sets `james_ads_trial 1` and `solo_weapon_balance 1`. Existing shortcut/solo launcher
continues loading this profile; no new launcher is needed.

The thirty-weapon reference snapshot remains research, not a blanket stat
replacement. No claim of improved hit rate, TTK, recoil feel or superior balance
is made from effective-field validation. The user can assess the trial in play.

## Verification

- 46Rust checks in9suites;17Node checks across ADS/roles/balance; native build passes.
- 47058decisions over50000commands match v16 for the previously covered pure-
  controller weapon set. Five new profiles have separate coverage/empty tests.
- Isolated run weapons-v19-20261026-182749 passed:11bot gun classes, readiness,
  lobby roundtrip, human+15bot return,32human/control/bot-strip cases, respawn.
- Ten reload cases cover five guns with/without Speedloader and all eight timing
  fields. Four ADS cases prove G2/reload and Flatline/role coexistence. Eight
  role cases prove effective field multipliers and attachment coexistence.
- Seven automatic loadout applications/control cases and three forced-modifier
  bot-strip cases passed. Actual physical dropping/pickup was not exercised.
- Native1.31.14.0 actual runtime and no detected script/native errors. Named
  modifiers neither duplicated nor refilled ammo; damage/rate/magazine checks pass.
- Normal startup weapons-v19-normal-20261026-183930 restored902named fields and
  established15bots+1human. All3normal save files stayed byte-identical through
  deployment and this startup check. Test session closed; harness disabled.

The first normal-watch attempt had a PowerShell parameter typo, corrected before
retry; it is retained privately as a watcher failure, not a gameplay failure.
This revision did not rerun the whole22-map study; that dataset remains frozenv18.

See RUNTIME.md/runtime-review.json for filtered diagnostics/effective values.
Functional package hashes were compared between source and the tested profile;
all staged files predated launch. Installed files match that tested manifest.
Native SHA256:9E8809146E17399B1CE572A5B479846C9A53633C48B7154A02159F47B19A4D6D.
Northstar core remains1.31.14; readiness bridge remains30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78.

## Backups and rollback

Private initial backup: weapon-integration-20261026-181718. Fresh normal
deployment backup: before-weapons-v19-deploy-20261026-183629, both under the
audit Notes/backups folder. Current saves were copied for protection, never
restored from historical surveys. Core/game installation files were not changed.

For only the new handling/role trial: set `james_ads_trial 0`,
`solo_weapon_balance 0` and `solo_weapon_balance_bots 0`, then respawn/reselect.
For full rollback, close the game, restore the backup native DLL, server.cfg,
enabledmods.json and prior reload folder; explicitly disable the newly installed
James.WeaponHandling0.2.0 and Solo.WeaponBalance0.1.0. Absence from enabledmods
can auto-enable an installed add-on. Never overwrite current save_data.
