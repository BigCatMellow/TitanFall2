# Repository review and low-clearance handoff fix

Reviewed origin/main d2dde49, frag lifecycle branch8962b2f and coverage-preflight
branch0e146d4 on October29. These are source candidates. The normal installed
DLL was checked independently: v23BC2C1019..., not the older v20 hash referenced
by the remote handoff. No game launch, deployment, settings or saves changed.

## Reproduced defect and fix

The low-clearance controller checked ordinary-corner eligibility only when
starting. Once active, it returned Duck before rechecking that predicate. If the
route advanced to a special traversal or unknown corner while still grounded,
it could suppress Jump/Speed for the remainder of its bounded crouch episode.
The caller clears those buttons whenever Intent::Duck is returned.

The fix rechecks ordinary metadata every command before either starting or
continuing the action. It yields immediately, clears its pending confirmation
and makes no further hull probe on a special/unknown corner. Existing timeout,
failure memory, grounded requirements and trace budget remain unchanged.

A new pure regression enters Duck on an ordinary path, then advances to an
off-mesh link, unknown255jump, or missing metadata before the next5Hzprobe. The
new test fails against the old eligibility condition (Duck rather than Normal)
and passes with the fix. All five clearance tests pass. This is policy-level
input ownership evidence, not physical Northstar passage validation.

## Useful additions and integration order

- Prefer the additive BT7274.FragDamageProbe and exact WeaponNotes concordance
  tooling first. The private grenade-script instrumenter is a separate higher
  integration-cost experiment; verify installed source anchors/load semantics
  before an isolated use. Command release, script stages, damage and kills stay
  distinct. The signed-handle fix accepts safe negative IDs except sentinel-1.
- The coverage-preflight branch adds map/epoch/span checks to A/B analysis. Its
  twelve Node fixtures pass locally; a structurally matched span is not proof
  of equal alive exposure, loadouts or successful traversal.
- Stall-target recovery is a useful independent behavior trial: two actual
  watchdog events,12sstrikewindow,8savoidance, bounded per-bot memory, visible
  target priority and fail-open fallback. It also feeds coordinated pursuit.
  Nearest-pursuit changes ONLY uncoordinated fallback; the current normal config
  has bot_team_coordination1, so that switch alone should not improve it.
- Low-clearance logic is a bounded duck trial, not slide/wall-run traversal.
  Test after this handoff fix, with verified eligible ordinary corners. The
  strict zero-code requirement intentionally declines the frequent255metadata.
- Keep the plain corner-height guard off pending reconciliation with our v22
  results. It uses a different all-corner vertical predicate from the tested
  local repair; a larger set of passing source tests does not override runtime
  evidence from the earlier rejected experiment.
- Pulse Blade1.1.0 restores native human recharge. That is a separate gameplay
  choice from the current50%recharge preference; retain the installed settings.
- The minimap fragment is integration research, not a ready-to-install HUD mod.

Main does NOT contain the local v23 Eden repair/pending-waypoint fixes, local
v21 offhand ownership, or v25/v26 prototype lane. New-main whole-DLL replacement
would lose that local source behavior. Reconcile the tested baseline and the
new independent flags before building an isolated integration candidate. New
flags default off; no normal promotion follows from this review.

## Checks actually performed

Node22.14.0:37checks across five main/frag diagnostic suites; separately12coverage
fixtures from0e146d4. The latter rerun eight existing cases plus four new ones;
these are49executions, not49distinct assertions or49game trials. All passed.
Pinned Rust nightly2025-09-11:32focused policy tests across action, route, skill,
clearance, targeting and input-probe modules passed before the fix. The changed
clearance suite then passed5tests instead of4 (33focused tests across the six
modules in the fixed source). Deliberate pre-fix regression failed as expected.
No new DLL build, Squirrel VM compilation, physics, CPU/p95 measurement, save
migration or runtime smoke was performed for these new repository candidates.

Normal stays v23BC2...; current saves and preferences are untouched. Raw logs,
DLLs and local reproducer executables remain private. The fix branch is based
on main, so its diff is a single policy fix/test plus this reviewed explanation;
it does not silently merge the separate frag or coverage experiments.
