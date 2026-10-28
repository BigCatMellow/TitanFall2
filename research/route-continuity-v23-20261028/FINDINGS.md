# Eden: reproduced blockage and bounded route repair

The latest played Full v20 session supports BT-7274's report: Eden had
709/3910 overlapping sustained low-progress pilot samples (18.13%), with all
15 bots represented in the main hotspot. The two Meadow rounds had zero such
samples. This was the unchanged v20 deployment, not the experimental v22 guard.

## Two distinct problems

The route search reaches the destination polygon, but the engine returns
straight waypoints only through the first traversal segment. Our follower
treated an empty remaining queue as route completion while its popped final
waypoint was still about 356 units away. Preserving that pending waypoint
fixes premature replanning; it did not, by itself, clear the physical Eden
crossing. The initial combat smoke's lower stall rate is preliminary and does
not override that directed failure.

Removing known traversal type 16 from explicit research queries produces a
southern route around the blockage. Larger search budgets and uniform costs
did not fix the original forward route. Static NPC-world-mask hull probes
showed height-dependent obstacles, but are not player collision clearance or
a verified jump arc. No game meshes, native ABI layouts or unknown arguments
were modified.

This follows the useful principles in the repository's
[NextBot/Detour research](../public-bot-systems-20261028/FINDINGS.md): preserve
an owned action until completion or bounded failure, then feed that failure
back into route selection. No third-party implementation was copied.

## Repair tested

`bot_eden_route_repair` combines pending-waypoint ownership with a temporary
detour after a failed type 16 segment. It applies only to Human-hull navigation
on `mp_eden`. A failure excludes that existing jump type from the next query
for at most eight seconds and only within 600 units of the failure location.
The original filter is restored immediately after each query. Progress and
waypoint watchdogs remain active. Death/hull reset clears the local feedback.

The separate global trial switches stay off. Aim, firing warm-up, damage,
weapons, human cooldowns and the current bot population are unchanged.

## Final frozen-build directed replay

Native SHA256: `BC2C1019D27F537F075611ED6B68A75591D1F2F9924BA8700D82A757BB1000F7`.
Same core 1.31.14 and installed bridge 1.0. One pilot in verified simulation 21
starts at (4120,-272,128), pursuing the same fixed target. The other 15 bots are
held stationary; their measured XY excursion after settling stays below 0.23 units.

| Phase | Repair | Duration | Closest observed distance to fixed target |
|---|---|---:|---:|
| Control | Off |90s|5522.07|
| Candidate | On |120s|1466.85|
| Respawn repeat | On |30s|3011.19|
| Disabled repeat | Off |10s|5522.26|

All directed samples recorded the actor alive with simulation 21. The repair
detected the initial stall, routed south, and escaped the original hotspot in
both on phases. Switching it off reproduced the blockage. Distances are
minimum sampled 3D distances, not travel times or precise arrival measurements.
The bot did not complete the entire fixed route within these windows. Later
traversal trouble remains visible; this is a targeted repair, not complete
navigation or whole-map validation.

Do not compare aggregate low-progress percentages from these manipulated
phases: the other bots are intentionally parked and some trace state is stale.
The analyzer suppresses those rates and retains directed movement separately.
The earlier natural-combat smoke is a separate build/cohort.

## Audit and next work

The first directed harness checked for a live pilot before respawn completed;
it was corrected to wait. A subsequent attempt did not maintain every other
bot's simulation override across staggered respawns, so it is not a clean
stationary-control comparison. The final harness maintains the overrides and
checks actual movement and the actor's simulation readback.

An intermediate test used invalid map ID `mp_complex` and stalled after the
lobby. Installed assets and prior surveys confirm `mp_complex3`. That attempt
is retained as incomplete; the harness now rejects unknown installed map IDs
before staging anything. It is not evidence of a native-mod transition fault.

The final run completed all five lifecycle phases with zero detected runtime
error markers. Effective Eden scope was 0/1/1/0/0, including zero on Complex while
the raw switch remained on. [Runtime evidence](eden-repair-runtime.json) and
[validation/deployment](validation.json) retain hashes and sanitized aggregates.
The exact tested native is installed in normal with only the Eden flag enabled.
Six current save files, enabledmods and all existing gameplay-setting values
were preserved. The launcher path/receipt checks passed. No human match on the
new deployment has been played yet. Isolated is restored to v20; no test remains.
Rollback was verified on a synthetic profile while preserving progress/settings.

Follow up with human Eden play,
remaining choke points and repeated combat comparisons before broadening the
repair to other maps or jump types. Do not strengthen aim to compensate for
navigation failures or infer K/D balance from this directed replay.
