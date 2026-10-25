# Combat review during the map survey

This is separate read-only work using completed v16 recordings. It does not
alter the current all-map trial settings or its existing report workers.
Current automatic reports live under active-fresh-batch.txt -> combat-evidence/.

## First three recordings

The old headline quick-reversal rate combined pilots and Titans. Splitting
events by the preceding actor snapshot gives:

| Map | Pilot-context quick reversals / switches | Titan-context quick reversals / switches |
|---|---:|---:|
| Black Water Canal |853/3650 (23.37%)|825/1989 (41.48%)|
| Colony |1340/3990 (33.58%)|2229/3764 (59.22%)|
| Complex |564/2441 (23.11%)|2406/4072 (59.09%)|

These are fractions of switch events, not missed shots, time spent confused,
or proven poor decisions. Context is at most2.1seconds old and may be stale
across death/embark. The report retains those ambiguous/dead contexts
separately. New exact actor diagnostics are prepared but not yet running.
An engage/engage pair does not prove both targets were visible simultaneously.

Of quick pilot-context reversals where both targets were recently observed
alive, only46/654 on Canal,29/971 on Colony,32/412 on Complex had both targets
within400 horizontal units. The ranking rule's close-threat override alone
is not a sufficient explanation from these snapshots. Visibility changes,
claim ordering and native Titan targeting need better discrimination.

Across these three logs,179 nonlegacy pilot combat snapshots occurred in
embark state. Source inspection shows the decision block is bypassed there,
while the old combat snapshot is still logged. Similar bypasses can occur
with a pet Titan or Titan enemy. Therefore a cached empty-magazine snapshot
cannot on its own diagnose failed reloading. Existing logs lack an active
marker; do not relabel these samples as confirmed idle/reload faults.

All three eligible combat reports list only mp_weapon_rspn101 (R-201).
The map survey covers navigation and this default pilot weapon; it does not
establish shotgun/sniper/SMG/projectile/heat weapon behavior. A later controlled
weapon matrix is useful after the frozen navigation pass, with tests for
range holds, empty/quiet reloads, retreat clearance and Titan transitions.

## Work completed

- Review-TargetSwitches.ps1 exports raw switch context and matched combat
  snapshots, explicitly retaining unknown freshness and actor data.
- Synthetic fixture verifies quick reversals, stale target rejection,
  low-health Titan classification, cached embark observations and post-result
  exclusion. First3 real recordings were processed successfully.
- A separate Watch-CombatEvidence worker processes each remaining archived
  match automatically; no game control or profile edits. Its snapshots and
  manifest are in the active batch/combat-evidence/tools folder. The worker
  has a bounded wait matching the size of the map queue.
- observation-v17-candidate adds exact actor labels and current-command
  combat freshness.34 tests, distribution build and47058-decision comparison
  pass. It is saved under Notes/candidates/observation-v17-20261025 and is
  NOT DEPLOYED. Real game validation is deferred until the queue finishes.

Next useful decisions: inspect Titan-specific switching with exact actor
data; reproduce the known Eden route obstruction with focused path/collision
diagnostics; then test representative weapon classes. No aim or global target
retention change is justified solely by the aggregate switch percentages.
