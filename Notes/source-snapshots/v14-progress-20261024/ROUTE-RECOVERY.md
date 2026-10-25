# v14 pilot route recovery

Built on the working team-observer-v12 local source, preserving buffer bounds,
map teardown, combat aim and team pursuit allocation. The rejected raw
persistence v13 prototype is unrelated and not included.

`bot_route_recovery` defaults to 0. With 1, legacy mode-6 Human-hull bots:

- Keep walking to the active final waypoint after popping it out of the
  queue. Previously an empty queue forced repeated path rebuilding before
  the bot reached that waypoint. A changed target, moved goal, watchdog,
  or reached/exhausted route can still request a new route. Terminal waypoint
  reuse is capped at 0.5 seconds so nearby movement/obstacles are reconsidered.
  Reuse requires observed ground progress toward that waypoint; stationary
  bots or bots sliding sideways along an obstacle retain immediate
  empty-route refresh rather than holding an obstructed waypoint.

- Remember up to eight failed routes near their current position. A failure
  affects unseen pursuit choices for two seconds, repeated failures up to
  eight seconds. Moving 192 units away or changing the goal by 320 units
  stops matching the record; different floors do not share records.
- Prefer another unblocked unseen target. Visible targets retain their
  existing priority; if every candidate is blocked, the original best
  candidate remains available.
- Record up to eight grounded breadcrumbs 128 units apart. A second stall near the
  same spot within 12 seconds can start a three-second retreat to recently
  traversed ground 160–600 units away and within 96 vertical units. This uses
  the existing bounded native path API; no new native function is called.
- If no retreat waypoint exists, repeated avoidance backs away diagonally
  on a stable per-bot side instead of holding forward and jumping.
- Stop retreating when close to the waypoint, after the deadline, or when a
  visible enemy takes priority. Death, hull changes and map teardown clear
  the new state; large teleports clear breadcrumb/failure history.

Titan controls, aim-error scale and team sizes are unchanged. State is
per-bot, fixed-capacity, and is not saved between maps or sessions.

BOT_ROUTE events report failed-goal skips and retreat destinations. BOT_TRACE
includes cumulative failed_goal_skips and retreats; BOT_FRAME records the
feature flag. Logs and replay samples can check subsequent displacement but
cannot prove clearance from a wall without terrain/video.

Ten new engine-independent regression tests cover active terminal waypoints, bounded storage,
expiration, local matching, moving targets, visible/only-enemy priority,
breadcrumb selection, floors, teleport/progress resets and retreat deadlines.
The full standalone suite has 27 tests. Deployment status/results belong in
the project Notes directory, not this implementation description.
