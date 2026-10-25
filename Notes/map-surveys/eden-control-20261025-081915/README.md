# Fresh-process Eden control — 2026-10-25

Purpose: determine whether the previous Eden FX-handle failure can reproduce
without a preceding Meadow match in the same process. This is one control
run, not proof of a particular leak or a guarantee of stability.

Fresh process launched08:19:18 local time directly into Eden. Fixed v16 DLL
C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075;
16 bots/8v8, dead human spectator, aim0.78,200 team score target and15-minute
cap, standard weapon/Titan behavior. No AI, jump behavior, particle settings
or effect limit changes. Native particle counters were not instrumented.

The observer harness and restore-only test persistence behavior match the
previous corrected survey. Only map order/count changed: Eden is first and
only map, and all resources begin in a fresh process. Random spawns, team
assignment and encounter histories remain uncontrolled.

Prior survey: ../20261025-000402. Meadow reached186–200 in682.5s; Eden then
failed around430s at last heartbeat86–67, on the600 FX-handle limit while
playing P_enemy_jump_jet_WR_trails near(4120,-355,126.09).

Read main/progress.json or main/Progress.txt for actual status. A score-limit
completion is distinct from a time cap or error. The watchdog stops only the
owned test game, saves logs and restores isolated config, cycle metadata,
persistence code/named saves and the original multi-map harness. Normal solo
profile/saves remain untouched. Backups are in backup/.

If the fresh run fails similarly, prior-map carryover is not necessary for
the failure. If it passes, one successful run cannot prove carryover caused
the earlier error; encounter-dependent behavior may also explain it.

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
