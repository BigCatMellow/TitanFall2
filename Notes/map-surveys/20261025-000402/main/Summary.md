# Survey stopped early — partial results

The unattended test ran, but did not complete the eight-map plan.

| Map | Recorded score (IMC–Militia) | Duration | Outcome |
|---|---:|---:|---|
| Meadow |186–200|11m22.5s|Completed the200-point winning-team target|
| Eden |86–67 (last heartbeat)|About7m10s before failure|Stopped on client particle-handle exhaustion|
| Remaining six maps |—|—|Not run|

At00:43:21, Eden reported:
Out of room for fx handles, effect P_enemy_jump_jet_WR_trails on player
entity14 at(4120,-355,126.09). Maximum PARTICLE_HANDLES_LIST_COUNT=600.
The error location matches the previously identified Eden navigation
bottleneck. Repeated wall-run/jump effects are relevant to investigate;
this observation does not prove whether the cause is a leak, repeated
recovery behavior, or effects carried over from the previous map.

The watchdog stopped the test process. Verified afterward: isolated config,
cycle metadata, persistence server script and named test save restored to
their backup hashes; survey metadata disabled. Normal save still matched
its pre-run hash. No test game or watchdog remained running when checked.

Raw data are preserved in raw-session.log and maps/. Reports for completed
Meadow and partial Eden are under reports/. The Eden log is a failed,
partial observation and must not be treated as a completed200-kill match.
The original attempt and startup correction remain documented in ../README.md.
