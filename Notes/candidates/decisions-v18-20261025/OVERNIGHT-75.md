# Overnight map survey — 2026-10-25

James authorized a 75-point team goal for the remaining maps and unattended
completion while asleep. The already-running Homestead round was preserved:
195–192 at the 15-minute cap. Kodai, Boomtown and Homestead are now complete.
Their configured goal was 200; keep that cohort separate from the shorter runs.

The overnight supervisor is running the other 19 supported maps at 75 points
per team, with a 15-minute fallback cap. Relic's actual start marker confirms
goal=75, engine_goal=75, bots=16, imc=8, militia=8 and observer_alive=0.
Native/core/readiness hashes, aim0.78 and bot loadouts remain frozen. Human
loadout restoration is disabled only for the inactive survey observer.

## Automation

- `tools/Run-OvernightSurvey.ps1` supervises one fresh-process worker per map.
- `tools/Run-CandidateSurvey.ps1 -Goal 75 -MapNames mp_relic02` checks the actual
  engine/harness goal, population and errors, exports reports and restores idle
  configuration. The supervisor supplies the selected map for each worker.
- Each map gets at most two attempts. Map-specific runtime/startup failures
  remain recorded; after the retry, the queue attempts the next map. Failed
  maps never count as successful coverage.
- Frozen-build changes, unrelated game processes, restoration failures and
  unexpected automation faults stop the queue for inspection.
- A temporary Windows system-awake request lasts only for the supervisor.
  It is released at exit; permanent power settings are not changed.
- Normal saved files are read/hash-checked, never restored from older backups.

Six fixture checks passed for completed/failed-map selection, map ordering,
meshless-arena exclusion, read-only planning, bounded goals/retries and core
cohort mismatch. Actual Relic startup verifies the 75-point runtime settings.
Run the planning fixtures with `./tests/survey_plan.ps1`.

Relic completed75–18 (IMC–Militia) at267.4s with reason score_limit. Reports
exported without error, idle configuration restored, and the supervisor
automatically launched Rise. Four maps are now complete across the two goal
settings. The lopsided short Relic result is an observation for later review,
not evidence for changing difficulty or a claim about its full-length outcome.

## Current session and recovery

Private root: `C:\Users\james\northstar-crash-audit\Notes\map-surveys`.
Read `current-v18-session.json`, then the current batch's `status.json`.
The new batch is `decisions-v18-overnight75-20261025`.

`status.json` contains live child progress and retained attempt failures.
`coverage.json` lists prior/new results, completed/failed/remaining maps and the
explicit meshless arena exclusion. `summary.json` is created when the supervisor
finishes. `complete_with_failures` means all scheduled maps were attempted,
with named failures still needing work; it does not mean every map passed.

Create `stop-after-current.txt` in the SUPERVISOR batch to stop after the current
map. Do not restart older stopped queues or overwrite current saves. Verify live
process ownership/status before touching files. Private full logs and personal
saved state remain outside Git. Native/source changes should wait for the frozen
survey to finish. No visual match watching or gameplay-balance conclusion is
implied by the unattended results.
