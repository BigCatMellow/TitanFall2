# James.BotDecisions

Script/native bridge for the switchable decisions-v18 candidate. Requires the
matching bp_ort DLL; install together, with the game closed. Do not install the
`James.DecisionTest` harness in the regular profile.

Uses documented [weapon script APIs](https://docs.northstar.tf/Modding/reference/respawn/entities/)
for readiness, ammo/energy cost, draining and shot counts. Reports every0.1s;
native samples expire after0.35s and must match the current weapon handle.
Missing/stale samples do not authorize an offhand request. No new native memory
offsets are introduced. Readiness is an observation, not proof of activation.

Pet-Titan eligibility uses `titan.e.isHotDropping`, the same field used by the
installed Northstar.CustomServers `_titan_npc.nut` WaitForHotdropToEnd function.
Only coordinated pilot targeting is filtered, before both visible choice and
pursuit fallback. Grounded nearby Titans and player Titans remain candidates.
Missing/stale eligibility also excludes a pet Titan until a fresh report.

Native feature switches (default0 for comparison/rollback):

- `bot_target_eligibility`: incoming pet-Titan exclusion.
- `bot_navigation_context`: clear movement watchdog anchor after commands that
  did not request path following. Genuine continuous navigation still times out.
- `bot_action_policy`: readiness-gated0.12s offhand requests, at most one start
  per second per weapon; retain the old health/timing eligibility windows.
  Ready defensive Stim/Phase intent survives reload suppression. Engine ability
  restrictions/cooldowns remain in effect; no ability strength changes.
- `bot_step_retry`: try the opposite strafe direction using the same wall and
  ground traces; stop if neither direction is safe.

BOT_WEAPON records the actual current native weapon separately from cached
BOT_COMBAT. BOT_READY supplies script readiness/clip/shot observations;
BOT_ACTION logs issued input/counters. Do not interpret repeated requests as
successful casts or two-second snapshots as shot-accurate outcome measurements.
Readiness requires enough resource for the larger of ammo-per-shot and current
energy cost (minimum1). The cost is a float because the engine API returns a
float. Tactical shot counters stayed at0 even when resources decreased during
tests, so they cannot be used as activation totals.

Default bots currently carry Grapple/frag. Their legacy activation branch does
not request those abilities; this update does not add Grapple/A-Wall placement
or change default loadouts. Mixed suits/guns are isolated test coverage only.

Normal human reload/recharge modifiers, aim0.78 and8v8 are separate and unchanged.
