# Eden route continuity investigation

Final outcome: the Eden-only pilot repair is validated and installed for playtest.
See [findings](FINDINGS.md), [runtime replay](eden-repair-runtime.json) and
[validation/deployment summary](validation.json). Global trial switches remain
off. The sections below preserve the sequence of hypotheses and experiments.

BT-7274 reported worse Eden pileups after the latest played session. The normal
profile was still Full v20 (3077878B...), not the experimental v22 height guard.
The fresh played data is separate from earlier unattended and played cohorts:
[derived played review](../played-eden-v20-20261028-evening/analysis.json).

Eden recorded 709/3910 sustained low-progress pilot samples (18.13%); the next
two Meadow rounds recorded 0/1441 and 0/1407. These overlapping samples are not
independent incidents. All 15 bot slots appeared in Eden's main hotspot. The
cells (4096,-256,128) and (4096,-384,128) held 513 of 709 low samples. This supports a
shared route problem; it does not prove a change between identical v20 builds.

## What the research contributes

The existing [public systems review](../public-bot-systems-20261028/FINDINGS.md)
and [navigation transfer notes](../navmesh-transfer-20261028/README.md) identify
three useful ideas: own an active movement action until completion/failure,
treat typed crossings separately from ordinary corners, and maintain a valid
route instead of indiscriminately discarding it. Primary references include
[Valve's NextBot follower](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/Path/NextBotPathFollow.cpp)
and [Detour's corridor](https://github.com/recastnavigation/recastnavigation/blob/main/DetourCrowd/Source/DetourPathCorridor.cpp).
No third-party implementation was copied.

The pinned [R5 SDK straight-path implementation](https://github.com/Mauler125/r5sdk/blob/c49e0d2123bc3ddb53419005ddd7c6ef73925faf/src/thirdparty/recast/Detour/Source/DetourNavMeshQuery.cpp)
documents segmented output at traversal links. R5 is a reference, not proof of
every Titanfall2 ABI detail. The actual R2 queries below establish the behavior
relevant here. No unknown native argument or buffer layout was changed. The
later detour experiment temporarily excludes the existing known type16 bit.
Installed Eden mesh Git blob hashes match the official NorthstarNavs
tree 0d3c1332ca40b7835f880251509da677184bec3e; no mesh assets were modified.

## Reproduced query behavior

32 explicit queries use the observed hotspot (4120,-272,128), four fixed goals,
both directions, 2048/8192 node budgets and original/uniform area costs. 28 return
routes; 4 reverse queries fail nearest-poly lookup. [Sanitized query results](query-probes.json)
retain geometry/status and a private-log hash, not account identifiers.

Every forward query reaches the requested destination polygon in its corridor,
but straight output ends at (3765.01,-253.311,150.366), the first traversal segment.
The far goal still has a projected 5180.5 unit gap. Increasing the budget/cost
variant does not remove this forward endpoint. Reverse partial/exhausted searches
remain a distinct issue; do not generalize the forward result to all routing.

The follower pops that final point into next_target_pos, leaving path_points
empty. On the next tick it rebuilds because the queue is empty, even though the
active point is still about 356 units away. This is a concrete ownership defect,
not evidence that finishing the point will solve every physical crossing.

## Narrow candidate

bot_route_continuity defaults OFF. When ON, a valid current corner farther than
the existing 45 unit arrival radius remains pending even when the remaining list
is empty. Goal changes over 600 units, forced replans, death/hull reset, the 3 second
no-progress watchdog and 5 second waypoint timeout retain their authority. It
does not broadly cache paths or enable the rejected/mixed height guard.
BOT_SEGMENT samples expose branch execution, not successful traversal.

Query diagnostics are explicit research-only constructors. Ordinary bots keep
the original 2048 node budget, costs and traversal filter. Aim, damage, weapons,
human bonuses and population settings are unchanged. Both profiles were freshly
backed up; current normal files and saves stay protected. Build uses pinned
offline release-debug with antivirus enabled and unchanged Cargo.lock.

## Validation

Native policy tests include Eden's pending-last-point case, arrival, invalid
route, disabled switch and nonfinite input. The phase analyzer prevents
low-progress history crossing phase boundaries and exports sanitized aggregates.
The isolated safety harness checks off/on, respawn, disable, lobby and new map.
A separate directed-walk variant freezes other bots on Eden and sends one pilot
from the recorded hotspot toward a fixed goal, with the switch off/on. These
manipulated tests remain separate from normal combat or human difficulty data.

Do not deploy solely on short sequential smoke rates. Follow with repeated
counterbalanced Eden/WarGames trials, Complex regression checks and Meadow
control. If finishing a pending segment still fails physically, investigate
bounded takeoff/landing ownership and supported-link feasibility next. Avoid a
global jump/aim buff or larger search budget without corresponding evidence.
