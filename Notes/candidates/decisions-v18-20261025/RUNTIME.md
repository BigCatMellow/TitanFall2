# Candidate runtime review

Run: decisions-v18-20261025-153058; watcher: passed; actual core: 1.31.14.0.

| Check | Result |
|---|---|
| watcher_completed_client_suite | PASS |
| actual_core_version | PASS |
| no_script_or_native_errors | PASS |
| all_phases_started | PASS |
| controlled_population_8v8 | PASS |
| human_plus_15_bot_return | PASS |
| six_weapon_classes_observed | PASS |
| ability_pulses_observed | PASS |
| no_sampled_filtered_hotdrop_selection | PASS |

| Phase | Map | Bots | Live pilot trace samples | Known hotdrop selections | Largest tactical pulse counter |
|---|---|---:|---:|---:|---:|
| 0 | mp_eden | 16 | 550 | 11 | 0 |
| 1 | mp_eden | 16 | 955 | 0 | 0 |
| 2 | mp_eden | 16 | 1015 | 0 | 13 |
| 3 | mp_complex3 | 16 | 907 | 0 | 12 |
| 4 | mp_black_water_canal | 16 | 891 | 0 | 11 |
| 6 | mp_eden | 15 | 597 | 0 | 0 |

Controlled smoke/integration coverage, not a randomized balance or stability guarantee. Ability shot/resource counters are observations, not cast-success totals. Native pulse counters reset across lives/hulls. Selected hotdrop counts use preceding reported state and two-second snapshots. Mixed loadouts occur only in the test harness. Private raw log and save data are not published.
