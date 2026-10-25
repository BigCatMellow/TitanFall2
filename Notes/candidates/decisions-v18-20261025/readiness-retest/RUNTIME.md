# Candidate runtime review

Run: decisions-v18-20261025-194409; watcher: passed; actual core: 1.31.14.0.

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
| final_cost_observed_and_respected | PASS |

| Phase | Map | Bots | Live pilot trace samples | Known hotdrop selections | Largest tactical pulse counter |
|---|---|---:|---:|---:|---:|
| 4 | mp_eden | 16 | 441 | 0 | 6 |
| 6 | mp_eden | 15 | 425 | 0 | 0 |

Controlled smoke/integration coverage, not a randomized balance or stability guarantee. Ability shot/resource counters are observations, not cast-success totals. Native pulse counters reset across lives/hulls. Selected hotdrop counts use preceding reported state and two-second snapshots. Mixed loadouts occur only in the test harness. Private raw log and save data are not published.
