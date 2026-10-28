# Public bot-system research and applicability

BT-7274 requested public-source research while safety changes are implemented
and tested. This review informs small experiments; it does not establish that
another game's bot controller is compatible with Titanfall2. No third-party
implementation was copied into the candidate by this review.

## Grenade task ownership and feasible throws

[YaPB TaskThrowExplosive](https://github.com/yapb/yapb/blob/b953ece2860340d4930736698d8cac8d22732f9c/src/tasks.cpp#L1524)
separates throwing from ordinary tasks, rejects a destination inside its blast
radius and tries a computed throw/toss before committing. Its
[trajectory calculation](https://github.com/yapb/yapb/blob/b953ece2860340d4930736698d8cac8d22732f9c/src/combat.cpp#L1522)
checks the ascending and descending sections. Its actual projectile lookup is
stronger completion evidence than repeatedly issuing input. The pinned tree
and selected files are private reference material under target/references;
the project's UNLICENSE was also read. Titanfall's physics/constants and
movement differ; do not transplant its numbers or velocity correction.

For our 153frag self-kills/71enemy kills, this supports explicit prepare,
release and projectile-outcome observations, blast clearance and bounded action
ownership. The current v21 draft addresses nearby clearance, short aim ownership
and forward approach restraint. It does not validate a full ballistic arc or
guarantee successful release. A collision-checked arc and projectile-relative
escape are follow-ups after diagnosing the actual failure.

## Traversal and recovery

[Valve NextBot PathFollower](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/Path/NextBotPathFollow.cpp)
handles ladders, climbs and gap jumps separately. It selects a landing point
for gap traversal and reports movement failure for a degenerate direction,
while preserving a path recomputed during a failure callback. Its control
interfaces are Source-specific. Useful lessons for recurring WarGames/Eden
cells are explicit traversal state, progress/completion criteria and bounded
failure handling, rather than increasing jump frequency. The v21 repeated-stall
pursuit skip is a small test, not a full traversal solution.

## Corridors and local movement

[Detour PathCorridor](https://github.com/recastnavigation/recastnavigation/blob/main/DetourCrowd/Source/DetourPathCorridor.cpp)
updates a route as the actor/target moves, offers local visibility/topology
optimization, and explicitly advances off-mesh connections. This suggests
auditing stale corners and traversal consumption. Titanfall's custom navigation
ABI/jump encoding must be verified first. Do not replace our fixed two-buffer
query or teardown handling with upstream buffers/types by assumption.

## Closest upstream

[bp-ort's README](https://github.com/catornot/bp-ort/blob/master/README.md)
describes an ongoing navigation/combat rewrite and planned wall-running work.
It is relevant upstream work, not proof a finished replacement is available.
Compare actual interfaces and implemented source before integrating experiments.

## Test order

1. Confirm grenade prepare/release/use/death observations in isolation.
2. Compare safety on/off on the same build/maps; separate natural combat from
   manipulated-health tests. Require retained useful throws, not just fewer throws.
3. Evaluate repeated-stall target changes and route progress at recurring cells.
4. Test respawn, switch-off, Titan/lobby/map changes and current save preservation.
5. Extend to arc safety, traversal states or corridor maintenance one at a time.

Aim0.78, the existing firing warm-up, weapon damage and human buffs stay fixed.
No claim of superior human difficulty or successful casts follows from requests.

## First implementation lesson

Our Pulse controller originally required `ready=true` on every held-input
frame. A weapon becoming busy during preparation could therefore end its own
request. The refined candidate separates initial permission from a bounded
continuation, with fresh same-weapon data still required. This is a testable
hypothesis inspired by task ownership, not a confirmed explanation of all drops.
Its Eden trial did not demonstrate a safety gain; do not deploy it on the
strength of the pattern or its passing unit tests. Verify actual outcomes.

Projectile speed samples alone cannot identify cancel/drop calls: inherited
velocity, early collisions and sampling delay also affect them. A release
signal includes both toss and cancel/drop. Further work needs the launch kind,
route clearance and projectile-relative danger/escape observations before
adjusting throwing power, trajectory constants or global movement settings.
