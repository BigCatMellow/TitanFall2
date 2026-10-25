# Fresh-process bot test batch

State: stopped_by_request
Updated: 2026-10-25T12:00:25.7174568-04:00
Current: 

Each match: fresh game process, fixed v16, aim error 0.78, 16 bots / 8v8, dead observer, 200-point team target, 15-minute cap.

| Map | State | Score | Seconds | Pilot stall samples | Quick target reversals |
|---|---|---|---:|---:|---:|
| mp_black_water_canal | complete | 156-178 | 891.5 | 1.24% | 29.5% |
| mp_colony02 | complete | 163-180 | 891.5 | 1.84% | 45.7% |
| mp_complex3 | complete | 199-155 | 891.5 | 2.54% | 45.3% |
| mp_crashsite3 | complete | 170-196 | 891.5 | 0.42% | 23.3% |
| mp_drydock | complete | 172-170 | 891.5 | 1.09% | 28.8% |
| mp_forwardbase_kodai | interrupted_by_user | last 141-98 | 745.1 | 1.16% | 24.5% |

Installed maps excluded from bot matches:
- mp_coliseum_column: Installed arena lacks bot navigation data; recorded as unsupported, not tested

Per-match directories contain logs, reports and restoration checks. Time-capped matches are not completed 200-point rounds. A fresh Eden pass cannot establish the cause of the previous Meadow-to-Eden FX error.

Paused at the user's request on2026-10-25 around12:00EDT. Five completed matches; Kodai interrupted at last recorded141-98 after745.1s. Its watcher reports game closure because we intentionally stopped that exact test process. Partial data is retained; this is not an observed game crash. All14 current-trial cleanup checks passed. Resume requires a new batch with fresh save/config baselines, including Kodai again.
