# All installed multiplayer maps — controlled bot survey

User authorized a complete map survey on2026-10-25. Inventory was discovered
from installed VPK directory files, excluding mp_common, rather than assumed
from a generic online list. See inventory.json and plan.json.

22 fresh-process 8v8 bot trials are queued:15 full-size multiplayer maps,
6 Live Fire arenas, and the original Coliseum. The installed Pillars variant
(mp_coliseum_column) has no navigation file in Northstar.CustomServers;
it is explicitly listed as unsupported/unbenchmarked, not counted as a pass.
No navigation file was substituted or downloaded.

Each trial keeps frozen nativev16, aim error0.78,16bots (8 per team) plus a
noncombat dead observer, TDM,200 winning-team points or15-minute engine cap.
A fresh game process starts for each map. The order prioritizes untested
full-size maps, then repeats Eden/Glitch/Angel City and covers the small arenas.
Live Fire/Coliseum results describe this same controlled TDM/8v8 experiment;
they do not establish support for their original special game modes, and
crowding/spawn/Titan restrictions may cause invalid or failed trials.

Expected duration is about6hours if most maps reach their time cap, plus
startup/report time. Per-map watchdog bound is25minutes. The report worker
waits up to580minutes to cover the whole queue. A failed match is archived,
restored and checked before the queue proceeds. Any cleanup verification
failure or unexpected other game stops the queue.

All staging is confined to the separate map-cycle-test-profile. Original
isolated config, script, mod metadata and named test saves are backed up
and restored after each trial. Persistence runs restore-only to prevent
spectator loadouts corrupting the test saves. Everyday solo files have an
additional baseline backup and per-map hash checks. Current loadouts are
never replaced with an older backup. No raw persistence buffers are used.

Status: status.json and Summary.md; current trial also has main/progress.json.
Reports: per-map main/reports for movement/combat; analysis/<map> for actual
waypoint motion and navigation geometry/stall plots. Report source snapshots
are in tools; manifest.json records their hashes. Survey logs are archived.

Counts of stalled samples are observations at2-second intervals, not unique
incidents or fractions of bots. Waypoint motion is sampled about every10s.
Fresh-process trials do not test cross-map resource accumulation, and a
single trial per map cannot establish general balance or prove absence of
crashes. Time-capped rounds are labeled separately from200-point wins.

To stop after the current trial finishes, run Stop-after-current.cmd in this
folder. The runner then restores/checks the profile and does not launch the
next match. Do not start a separate game or alter the test profile while
this queue is active.
Full-map queue startup verified10:23EDT: Black Water Canal reached measurement,16bots,8perteam,dead observer,goal/engine_goal200; BOT_MOTION confirms aim_error_scale0.78. Heartbeats/kills progressing, no reported failure or stderr. Both long-running workers active. Next steps can be read from active-fresh-batch.txt; no need to prompt for advancing maps.
