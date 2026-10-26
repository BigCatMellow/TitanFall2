# Weapon mapping and bot coverage correction — 2026-10-26

Status: **source-only candidate**. No live Northstar runtime verification,
installation, deployment, saved-loadout edit, aim change, or damage/fire-rate
change is claimed. The private unattended v18 survey state is unknown from
GitHub; inspect its live supervisor status before staging anything on James's PC.

## Confirmed mapping mistake

Northstar's weapon-code reference identifies:

| Classname | Actual pilot weapon | Reference MP near damage / RPM | Base reload / empty |
| --- | --- | --- | --- |
| `mp_weapon_alternator_smg` | Alternator | 35 / 600 | 2.30s / 2.70s |
| `mp_weapon_hemlok_smg` | Volt | 25 / 660 | 1.50s / 2.00s |

The original James.WeaponReload 1.0.0 modifier targeted `hemlok_smg` while
calling it Alternator. Therefore its eight archived runtime comparisons
validated G2, **Volt**, R-201 and CAR (with/without Speedloader), not the
Alternator. Its old numeric test outputs remain historically intact, with
prominent errata in the relevant notes and research report. Neither of the
above classnames is the Hemlok burst rifle (`mp_weapon_hemlok`).

Candidate 1.0.1 **preserves the existing four-gun behavior** and includes the
true Alternator as a fifth supported classname with the same local-human-only
0.9 multiplier. Without Speedloader, its *expected engine settings* are
2.30 -> 2.07s normal and 2.70 -> 2.43s empty; these are arithmetic
expectations, not measured results. With Speedloader, the expected totals are
2.30 * 0.7 * 0.9 = 1.449s and 2.70 * 0.7 * 0.9 = 1.701s.
Actual reload animations and damage/hits have not been retested.

## Bot combat policy coverage

The native `combat_decisions.rs` class-specific range/reload selector lacked
five ordinary pilot weapons. This candidate maps them to **existing** policy
groups, without changing the policy constants or other weapons:

| Newly handled class | Existing profile | Near / far decision thresholds |
| --- | --- | --- |
| Alternator (`alternator_smg`) | SMG | 180 / 650 engine units |
| Mastiff (`mastiff`) | Shotgun | 90 / 300 |
| Devotion (`esaw`) | Rifle/LMG | 280 / 1000 |
| Wingman (`wingman`) | Precision | 400 / 1350 |
| P2016 (`semipistol`) | Close sidearm/SMG | 180 / 650 |

These are movement/reload heuristics, **not** damage falloff distances or
claims of optimal effectiveness. Cold War (`pulse_lmg`) needs four rounds per
burst, so generic `clip == 0` reload handling would be insufficient; it is
intentionally left for ammo-minimum-aware work. Anti-Titan lock-on/charge/heat
weapons need a separate decision policy and are also unchanged.

## Verification available and remaining

- The standalone `tests/weapon_mapping.rs` checks that the human-mod script's
  five classnames exactly match five KeyValues overlays, all eight reload
  timing fields are scaled, and the manifest names both SMGs.
- `combat_decisions.rs` has two new native-independent tests: coverage of
  ordinary pilot classnames and empty-magazine reloads for the five additions.
- Run `tools/Test-Project.ps1` with the pinned Windows nightly Rust toolchain;
  it now includes the mapping test. Then rebuild the native DLL with the
  documented toolchain and check source/module hashes.
- On a **backed-up isolated profile after the frozen survey ends**, test all
  five human guns with and without Speedloader in actual Northstar. Verify
  normal/empty/checkpoint settings, duplicate modifier prevention, attachments,
  bot exclusion and transfer-to-bot stripping (previously unexercised).
- Test a representative mixed-weapon bot matrix, map transition/lobby return,
  all 15 bots plus one human, save hashes and errors before considering a
  normal-profile installation. Do not infer a successful test from a log
  count or from this offline source change.

Sources:

- [Northstar's canonical weapon-code list](https://docs.northstar.tf/Wiki/hosting-a-server-with-northstar/server-settings/file-names/)
- [Published reference weapon KeyValues](https://github.com/BigSpice/TitanFall-2-Skin-Modding/tree/main/Weapon_Scripts)
- Historical repo reports: `Notes/WEAPON-RELOAD.md`,
  `Notes/WEAPON-REVIEW-20261024.md`,
  `research/weapons-abilities-20261025/FINDINGS.md`
