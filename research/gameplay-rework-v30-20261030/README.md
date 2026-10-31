# Gameplay rework review — 2026-10-30

BT-7274 requested changes to gameplay rules and decision structure beyond scalar
skill tuning. Preserve the stable native and saves. v29 escape/crouch remains a
separate experimental candidate; do not bundle it into this script-only change.

## First change: treat bot frag mistakes as recoverable

The latest two played Full rounds recorded 46 frag self-deaths versus21enemy
pilot deaths. The new BT7274.FragSelfDamage rule scales only bot-pilot own-frag
damage by0.25. It changes the consequence rather than pretending movement AI
has become smarter. Enemy frags remain dangerous; aim/reaction/damage to enemies
are preserved. Re-evaluate human pressure and match flow after real play: bots
living longer may increase difficulty without better shooting. No guarantee
that a75%damage reduction yields75%fewer deaths.

## Next structural trials, ranked

1. **Recovery as a bounded action with an explicit failure outcome.** Latest
   Glitch had46/2452low-progress pilot samples,44with >=720degrees yaw; no sampled
   low-progress window exceeded20%jump commands. Implement a narrow repeated
   route/corner failure memory and handoff rather than adding more jumping.
   v23 has an Eden-only proven repair; route_guard already has partial-route
   throttles and target cooldowns; v28 stall/nearest/height trials were mixed.
   Extend the specific demonstrated failure, not enable all those flags.
   Measure repeat visits / successful exits / time to rejoin combat, not only
   command counts. Expire failure memory and reset on map/life boundaries.

2. **Choose a reachable firing position, separately from the target.** Over half
   the latest visible human-pilot engagement samples had >180units height gap.
   Current basic_combat.rs height_followups selects nearby hidden cover and
   holds; this is defensive, not a planner for an attack position. Add a bounded
   search of reachable nearby nav points with a usable firing line and weapon
   range, then commit briefly to one position. Visible urgent threats may still
   interrupt; no knowledge of enemies outside actual visibility/last-known
   memory. Verify full route/hull/ground and exit on failure. Avoid globally
   forcing height guard: previous trials worsened several maps.

3. **Give teammates positions, not only enemy assignments.** coordination.rs
   currently tracks target supporters/commitment and separation_side. Add
   short-lived reservations for approach/firing positions to reduce crowds and
   alternate firing lanes. Preserve immediate attacks on nearby threats. Expire
   on death/target/map change; never force distant detours solely for variety.
   This is an extension of existing coordination, not a missing-team-AI claim.

4. **Make action ownership explicit.** Grenade escape's v29 self-cancel bug is a
   concrete example: an entry condition incorrectly cancelled continuation.
   A shared arbitration boundary should distinguish enter/continue/finish/fail,
   let one locomotion action own movement, and restore navigation from actual
   position afterward. Keep aim/fire separately controlled. Prototype behind a
   switch with lifecycle tests before refactoring all of basic_combat at once.

5. **Abilities selected for verified outcomes.** Current Pulse gates a ready
   weapon and emits timed requests; requests are not confirmed casts. Observe
   cooldown/resource/effect transitions and retry only after bounded failure.
   Movement context should choose Stim for closing/escaping, not an aim buff;
   grenade self-damage protection must not silently extend to every explosive.

Do not change weapon damage based on this session: only four qualifying
human-to-bot gun episodes. Movement is already useful (under9%of hold samples
near-stationary). Preserve that while separating positioning from shooting.

## Primary-source research and adaptation limits

- Northstar's [DamageInfo API](https://docs.northstar.tf/Modding/reference/respawn/native_server/damageinfo/)
  exposes damage getters/setters. Installed Northstar1.31.14
  _codecallbacks_common.gnut / mp/_codecallbacks.gnut verifies source callbacks
  run before final observers. Use this hook rather than override grenade files.
- Valve's [NextBot action system](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/NextBotBehavior.h)
  makes continuation, replacement, suspension and completion explicit, with
  prioritized event transitions. Architectural reference for input ownership;
  not directly compatible native code or a replacement for our engine bindings.
- Valve's [PathFollower](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/NextBot/Path/NextBotPathFollow.cpp)
  treats fallen-off/unreachable path segments as failure and invalidates them,
  and bounds local obstacle avoidance with timers. Adapt failure/handoff ideas;
  do not import Source navmesh types, offsets or TF2 locomotion assumptions.
- Valve's [TF bot attack action](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/tf/bot/behavior/tf_bot_attack.cpp)
  separates approach from aim/fire and uses recent visibility / last-known
  positions. Supports the separation proposed above; Titanfall traversal and
  weapon handling still require our own validation.

These are proposed follow-ups, not installed behavior. Only the narrow frag
self-damage rule is being implemented this turn. Validate each change in isolation
on Glitch/Drydock plus a previously good map and gather human feedback. Keep
notebook gaps, synthetic tests, bot-observer matches and actual play separate.

## Installation and measured verification

Installed in the normal solo profile after the isolated checks. Same shortcuts;
no game left running. Fresh current backup created, all current saves preserved.
Normal native remains BC2C1019...; isolated used the3077878B...baseline on core
1.31.14. New mod disabled per-version in isolated after cleanup. No v29 native
features promoted. Public evidence: validation.json (52health cases,11real
scaled self-hit events:10Drydock/1Glitch,0detected runtime errors). Four focused
reviewer regression tests passed; PowerShell parsing and source/installed hash
checks passed. This is a script-only change, so no Rust rebuild was needed.

Rollback immediately with `bt7274_bot_frag_self_damage 0`. Persistent closed-game rollback: tools/Install-FragSelfDamage.ps1
-Rollback. It disables only this mod/removes its three config keys and retains
current progress. Private deployment receipt records the exact fresh backup.
The first launcher attempt failed on Windows PowerShell Get-FileHash autoloading
before game/mod changes; corrected to explicit .NET hashing. The completed
runtime validation is a separate attempt, not a claim the failed attempt passed.
