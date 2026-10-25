# OctBots and coordination assessment

Inspected 2026-10-24 after the player reported disorganization in the working
8v8 setup. No runtime changes were made during this assessment.

## What exists

- The experimental component is `octbots`, in this same source workspace.
  A previous `octbots.dll` is also in the 20261023 plugin backup; it is not
  loaded in the current solo profile.
- `octbots/src/behavior.rs` combines a behavior tree with targeting, movement,
  asynchronous path requests, and mode-specific actions.
- `octbots/src/movement.rs` has wallrunning, fence traversal, reachability
  checks, and movement/aim separation.
- `octbots/src/gamemode_cp.rs` shares capture-point ownership claims among
  teammates. `gamemode_ctf.rs` uses teammate positions in objective decisions.
- Those are useful precedents for coordination. Deathmatch targeting still
  largely picks threats by visibility/distance and per-bot preferences; this
  is not evidence of a finished squad-tactics system.
- The published v1.0.0 notes list higher computation cost and an inability
  for OctBots to control Titans. The checked-out source contains prototype
  Titan embark/ability actions and a separate Titan path branch. Those
  prototypes require validation before relying on them in the solo setup.

Upstream release notes:
https://github.com/catornot/bp-ort/releases/tag/v1.0.0

## Integration constraints

Both plugins must be built with matching Rust/interface versions. Copying
the older backup DLL beside the patched main plugin is not a validated
combination. OctBots loads its own versioned `.navmesh` files; none were found
in the checked active profile or game output locations. Missing maps may
trigger generation work. Its navigation is not a small standalone function
that can be substituted for the native legacy pathfinder.

The confirmed earlier memory corruption was in the legacy native pathfinder
output buffers. That finding does not establish the stability of OctBots;
its crashes, loading behavior, map transitions, and performance need their
own test.

## Recommended next implementation

Start with coordination in the current legacy implementation. Its
`basic_combat` selects the closest visible threat, then the closest enemy.
The existing last-shot reservation filter is disabled in that call, with an
upstream comment that it made behavior worse. Simply enabling it again is
not a tested improvement.

A new selector should score distance, how many teammates are already chasing
the candidate, immediate threats, and continuity with the current target.
Claims must be team-specific, expire when a bot/target dies, and never forbid
shooting the only available enemy. This can reduce dogpiling and target
switching while retaining the existing Titan controls and 0.80 aim preset.
Path selection/avoidance remains a separate problem; better coordination
alone cannot repair missing navigation coverage.

In parallel as a later independent experiment, build a matching OctBots/main
plugin pair in a separate profile, prepare map navigation, and compare pilot
movement and frame cost. If useful, evaluate an explicit pilot-only OctBots
mode with legacy Titan control, including embark/disembark transitions and
map-change cleanup. This hybrid has not yet been implemented or tested.
