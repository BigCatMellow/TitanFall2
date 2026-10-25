# Unattended v16 map survey

16 bots, 8v8; local client spectating. Fixed v16 build and aim error 0.78.
Team score target: 200; timed-out maps are capped observations, not completed 200-kill matches.

| Map | Score | Minutes | Ending | Pilot stall samples | Quick target switch-backs |
|---|---|---:|---|---:|---:|
| mp_eden | 161-145 | 14.9 | time_limit_or_rules | 6.23% | 34.2% |

Stall percentages describe two-second pilot samples after the population warmup. Intentional range holds are excluded from the stall heuristic. Quick switch-backs are target reversals within half a second; some are legitimate.

This unattended run is useful for map navigation, combat consistency and stability. It does not establish difficulty against a moving human or exact frame rate.

Per-map score/kill rosters, raw logs, movement replays and combat summaries are stored beside this report. No AI or weapon tuning was changed during the run.

## Fresh Eden control outcome

Completed on 2026-10-25: 161–145, 891.5 seconds after measurement warmup,
valid time_limit_or_rules ending. The engine time limit ended the match;
neither team reached 200. All 16 bots remained present and the observer
stayed dead. No script/native errors or FX-handle exhaustion were recorded.
All isolated config, cycle metadata, persistence code, original multi-map
harness and named saves were restored and hash-verified; normal save unchanged.

Pilot stall samples: 306 / 4914 (6.23%). The leading cluster is still near
4096,-256,128 (135 samples), with another 37 near4096,-384,128. The previous
crash location lies here, but this run experienced the same area without
exhausting FX handles. Quick A-to-B-to-A target reversals:2261 /6606 (34.2%).
These are descriptive counters, not proof that every reversal is a mistake.

The earlier Meadow-to-Eden run failed near430 seconds. This fresh run lasted
more than twice as long without the error, but does not prove map carryover
caused it. Encounter-dependent reproduction and an effects lifetime issue
remain possible. No AI, aim, weapons, or effects were changed for this test.
