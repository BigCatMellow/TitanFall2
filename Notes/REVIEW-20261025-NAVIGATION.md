# Navigation investigation — 2026-10-25

No native bot, aim, game configuration, navigation mesh, or normal save
changes were deployed during this investigation. The v16 comparison queue
continues independently; read active-fresh-batch.txt and its status.json.

## Verified match result

The fresh Eden repeat completed at the engine time limit: IMC102–Militia146,
891.5 seconds of measurement, all16 bots present, no reported FX/script/native
error. This was not a200-point win. All eight restoration checks passed,
including the normal loadout save. Glitch then started automatically.

There are now two completed fresh-process Eden controls without the earlier
600-FX-handle failure. The same localized navigation stall exists in both.
This separates a reproducible movement problem from a crash that has not
yet reproduced in a fresh process; it does not establish the old FX cause.

The repeat had401 stalled pilot two-second samples,8.38% of eligible live
pilot samples. The first fresh control had306,6.23%. Random encounters,
targets and deaths differ; this comparison alone is not a regression test.

## New waypoint evidence

The existing BOT_TRACE tx/ty/tz fields describe the selected enemy. During
embark the actual navigation goal is the pet Titan, and even during pursuit
the next route point differs from the enemy. Prior target-height metrics
must not be described as waypoint height.

Review-WaypointMotion.ps1 reads actual BOT_MOTION next coordinates and joins
preceding player/trace context. Survey warmup and post-result lines are
excluded. It keeps pilot context only with a recent player sample and a
nearby position, excluding low-health Titans. Motion is approximately every
10 seconds; low progress is below50 units endpoint XY displacement. Counts
are sampled observations, not distinct incidents or continuous video.

| Eden recording | Eligible pilot navigation motion samples | Low-progress samples | Low progress with next-point height over180 |
|---|---:|---:|---:|
| Earlier FX failure, partial round |249|24|0|
| First fresh control |660|63|1|
| Fresh repeat |624|83|0|

At the repeat's hotspot (X4000–4300,Y-450–-150),77 low-progress motion
samples were recorded. Of those,54 pointed at exactly
(3765.0068,-253.31079,150.36554), with another13 at adjacent vertices
(3757.0068,-213.31079,150.36554) or
(3757.0068,-269.3108,150.36554). Many bots stopped around X4120.0313,
with a route point roughly350–420 horizontal units away. Typical next-point
height difference in the main hotspot cells was22–23 units, rather than
hundreds. The decoded small mesh has those higher route vertices in
surface group62; nearby lower surfaces are group2. Group IDs alone do not
establish connectivity or collision clearance.

The horizontal-only waypoint-consumption code is still a valid review lead,
but these sampled next points do not prove that vertical waypoint skipping
causes the hotspot. A repeated obstruction or unsupported route transition
is a stronger reproduction target than changing all vertical tolerances.
The next point can also be stale during recovery; the report explicitly
does not infer the native corridor or a clear physical segment from it.

## Hull evidence and limits

Export-EngineHullContext.ps1 inspected installed server.dll offline, checked
the exact GetNavMeshHullIndex function instructions, and decoded its table:
Human0→mesh slot0, Medium1→2, FlyingVehicle2→3, Small3→0, Titan4→3.
The file also contains a contiguous suffix-pointer array
small/med_short/medium/large. Loader use of that array and possible live
patches have not been traced, so slot0→small.nm is not asserted as fully
verified runtime behavior. No game memory was inspected or changed.

Installed server.dll SHA256:
A5CA3A25C8AE56952A26141B0F6CDCB6C19086C8C39013F7CB345D5D723661AF.
Full evidence: map-context/engine-hulls.json.

## Automatic remaining analysis

Watch-FreshBatchAnalysis.ps1 runs separately from the match queue and only
reads archived completed-match logs/installed meshes. It generates each
map's waypoint report and navigation PNG with observed stalls, without
editing game profiles or starting/stopping games. Its70-minute deadline
does not affect the game runner. Check the active batch's analysis/status.json,
analysis/Summary.md and worker.stderr.log. Initial Eden processing completed
and its hotspot PNG was visually checked; the remaining maps are pending.

Next diagnostics, after frozen matches: capture selected start/end poly refs,
projected positions, straight-path traversal flags/jump types and a bounded
collision/hull trace at repeated stalls. Confirm the live hull/mesh mapping.
Use a separate diagnostic candidate in the isolated profile and compare
Eden against Glitch/Angel City before deploying any movement changes.
Avoid modifying all maps or aim to compensate for one localized route.

## Validation and state preservation

The motion reader parsed all recorded motion lines in all three Eden logs.
A synthetic fixture verified warmup/end exclusions, low-health Titan
exclusion and elevated-nearby waypoint classification. The worker passed
PowerShell parsing and completed its initial real report without errors.

At09:07 both solo and isolated bp_ort.dll hashes remained
C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075.
The normal named loadout save remained
A77FB6C2ECC2A3E48BCA6A273269934499721E46E6A9A7F7833B0EE2142444E5.

The running analysis worker PID is251472; the original match queue PID is
246268. Do not launch another test or alter the isolated profile during the
queue. These PIDs are historical identifiers; verify current status before
acting on any process.

2026-10-25 10:13 verified completion: the entire fresh-batch-20261025-083855 queue and read-only analysis worker finished at09:27. Eden102-146 and Glitch125-180 both reached891.5s engine caps; Angel City200-150 reached score limit in757.7s. No recorded match failures or analysis errors. Pilot stall sample rates:Eden8.38%,Glitch1.36%,Angel City0.85%; these are sample fractions, not percentages of bots or unique incidents. All24 per-match restoration checks passed. Solo v16 DLL and normal named save hashes still match baseline. Former runner/report worker PIDs are no longer active. No new gameplay changes were deployed. Primary next reproduction target remains the repeated Eden obstruction/route transition; target reversal frequencies alone do not establish a global combat problem. Reports: active-fresh-batch.txt -> Summary.md and analysis/Summary.md.
