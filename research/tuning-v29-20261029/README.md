# v29: clearance eligibility and owned-frag escape

BT-7274 authorized tuning after the v28 screen. This candidate preserves the
v23 Eden-only repair and the existing aim0.78, firing warm-up0.8s, damage,
weapon rates, 8v8 setup and human modifiers. Normal deployment is unchanged.

Two default-off changes are tested independently:

- Early clearance now accepts the ordinary non-traversal marker255, zero flags,
  grounded near-level paths and speeds0–280. Two real DuckOnly hull confirmations
  are required. Special links, upward jumps and unsafe fits yield immediately;
  the existing time limit, failed-location memory and traversal handoff remain.
- Owned-frag escape receives actual projectile observations through an additive
  server mod. Fresh, nearby, same-floor, non-departing projectiles can request
  a bounded ground move away. Relative projectile/owner velocity matters. Three
  stand-hull/ground-checked headings are tried at most every0.2s. Jump, duck,
  use, offhand actions, recovery, Titans and stale observations yield. Aim and
  attack/reload decisions remain intact. Release requests a fresh route.

`bot_frag_escape` and `bt7274_frag_awareness` default0. The strict throw gate,
height trial, stall memory and nearest override remain off in these cells.
No grenade fuse, physics or damage edits. Observation age is time since first
sighting, not verified fuse age. Owned grenades only; enemy grenades are outside
this first candidate's scope.

## Marker evidence

The related r5sdk Detour header at pinned commit c49e0d2123bc3ddb53419005ddd7c6ef73925faf
[defines DT_NULL_TRAVERSE_TYPE as0xff](https://github.com/Mauler125/r5sdk/blob/c49e0d2123bc3ddb53419005ddd7c6ef73925faf/src/thirdparty/recast/Detour/Include/DetourNavMesh.h#L101).
The local wrapper also initializes ordinary traversal slots to255. Existing
Relic observations include a grounded speed0, zero-flags/255, 125-unit corner
with16.5-unit rise and DuckOnly fit. This supports fixing the old impossible
code0 gate; it does not import another engine's ABI or establish runtime benefit.
Actual hull traces and action events remain required.

## Validation and measurement

Pinned locked offline Windows build.125Rust tests/22suites and109Node tests/21files,
plus migration/preset fixtures, passed before the final runtime smoke. Lock bytes
remain E4F8434813F688AF4FB5184EAEF4876A7F72F79C1D6B2A4DAB69C7BF2B89AE41.
Candidate native:6AB62D1B7F7E432947D3E2A4CFE69C0ACACA5D598FF333F8DA2061897FE7B545.

The first server-script attempt failed a struct-declaration syntax check and was
corrected. A subsequent absolute-velocity attempt was intentionally stopped and
superseded by relative velocity. Neither is counted as a passed test or match.
Final lifecycle and matched-round outcomes are recorded separately after review.

The tuning cohort uses MAP_SURVEY_TUNING with explicit cell readbacks, separate
from v28. Clockless notebook/fault warnings are retained conservatively. Pilot
low-progress percentages are overlapping samples, not independent stuck events.
Escape move samples are commands, not confirmed escapes. Local probe-call timings
are not overall frame p95. No visual spectator observation occurred. Current
saves are backed up but never restored from historical test snapshots. Raw logs,
entity handles, account data, game assets and binaries remain private.
