# Legacy bot movement recovery

After a successful map transition to Kodai, the player reported bots jumping
in place. The v7 log contains repeated nearest-polygon failures. A zero in
the old error message was an unfilled output point, not proof that the bot
was at world origin. Errors now report the requested positions.

Confirmed source defects:

- Obstacle avoidance set the cooldown timestamp before checking it, preventing
  a new jump press from starting. Its `saturating_sub(0)` also never released
  a hold inherited from normal navigation.
- Normal navigation requested jumps even on flat routes (`height >= -40`).
- A bot that failed to reach a waypoint for five seconds retried avoidance
  indefinitely without invalidating that route.
- On initial path failure the bot recovered using its previous facing angle,
  and a failed query could leave stale waypoint data.

Build `navigation-motion-v10` uses a shared four-command jump pulse with a
0.6-second cooldown, requests route jumps for raised waypoints, discards
stalled/failed routes, and faces the opponent during fallback movement.
It allows 1.2 seconds of recovery before calculating another route, rather
than immediately returning to the same blocked waypoint. Navigation starts
at `m_vecAbsOrigin` (feet), while visibility and aiming retain the existing
eye-position calls. The v8 telemetry showed a consistent 60-unit difference
between the requested start and the player origin. An airborne raw goal is
no longer appended after the native reachable straight-path endpoint.

The longer v9 Kodai test exposed a second reset loop: a new partial route's
first point can be the current location. Reaching/replacing those points
continually resets the waypoint timer without horizontal progress. v10 adds
a separate displacement watchdog: moving at least 80 horizontal units resets
it; three seconds of insufficient displacement initiates recovery. Route
recalculation does not reset it. Arriving at the requested goal clears it.
The prior native-buffer and map-lifecycle fixes are retained.

`bot_motion_debug 1` logs each bot's mode, health, position, ten-second
horizontal displacement, velocity, input, and remaining route nodes. It
defaults to zero. This distinguishes successful joins from working movement.

Two jump-state, three movement-watchdog, and three navigation-buffer tests
pass. The
isolated seven-bot regression starts on Kodai, then changes to Relic and
Wargames. v8 reached all three maps with moving bots and combat on Relic and
Wargames, but some Kodai ledges still caused stalls. v9 also completed both
map changes, but its Kodai movement regressed (37 of 49 alive movement samples
had less than 50 units of displacement), so it was not deployed. The final
v10 live test has now reached all three maps with 21 bot joins and no script
errors, native access violations, or panics. Every bot recorded at least 200
units of horizontal displacement on every map. Kodai recorded 49 movement
samples (47 alive), with five alive samples below 50 units of displacement;
14 samples show damage or death. Relic recorded 28 samples, with no alive
samples below 50 units and seven damaged/dead samples. Wargames movement
was also confirmed after the second map change. This is a short regression
run, not a guarantee that the legacy NPC navmesh supports every pilot route.

The final DLL has SHA256
`18E8F2DB00FBDB5667BAB7841465C202528A46BD90C4E1FF39216FAB03AD7AD3`.
It is installed in the regular and solo profiles. The isolated cycle harness
is not installed in either. The solo config explicitly selects combat mode
6 and retains movement diagnostics, seven bots, and the relaxed aim setting.
Previous DLLs/config and the tested build are saved under
`northstar-crash-audit/navigation-motion-v10`.
