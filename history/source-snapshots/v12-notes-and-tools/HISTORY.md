# Change and investigation history

## Earlier setup and confirmed crash findings

Northstar and legacy bp_ort were installed for solo multiplayer with player
bots. OctBots was tried earlier and an old DLL remains in the 20261023 backup.
The current working profiles omit it.

An authentication failure named `r2-pc.stryder.respawn.com` and reported DNS
lookup failure. Public DNS checks at the time also failed. Later recovery
overlapped a reinstall, so those events do not establish that local changes
caused the authentication outage.

The repeated legacy spawn/path crash had a confirmed native memory error:
Titanfall's modified Detour `findPath` writes both polygon references and one
traversal byte per polygon, up to 256. An eight-byte stack placeholder for
the second output overflowed. The fork now owns two correctly sized buffers
and validates native output counts. See CRASH-FIX.md in the checkout.

## v7 — map lifecycle

Native navigation queries and bot state are cleared across server VM/map
changes. A server script publishes match readiness after the intro, joins
are spaced 0.5 seconds apart, and fake-client creation runs after the server
physics callback rather than the general HostState frame. Polling the script
VM from that frame was rejected after failed tests. Thread IDs alone did not
prove a worker race. A seven-bot Eden → Relic → Wargames test passed.

## v8–v10 — movement

Fixed a jump hold that never decreased, corrected obstacle cooldown handling,
and stopped requesting jumps continuously on flat routes. Navigation uses
feet rather than eye position. v9 exposed a partial-route loop and was not
deployed. v10 detects actual horizontal progress independently of waypoint
replacement and initiates bounded recovery. Seven-bot movement and combat
were observed across Kodai, Relic and Wargames. Individual stalls remained.

## v11 — skill and steering

Added `bot_aim_error_scale 0.8` to the relaxed solo preset: 20% less angular
aiming error, not a measured 20% change in hit rate. Fixed yaw turns across
the -180/+180 boundary, bounded navigation turns, skipped nearby duplicate
nodes, and reduced repeated recovery jumping. Eleven regression tests passed.

## 8v8 configuration

Raised manager max/target to 16 total players (one human, 15 bots). The solo
launcher explicitly requests the 16-player playlist cap. Fifteen bot joins,
movement, and combat were observed; BT-7274 reported the result was great.
The code's 32-client ceiling has not been stress-tested as a solo match.

## Glitch round reviewed on 2026-10-24

From 13:48:28 to 13:56:25, the v11 log recorded 15 bots and 702 movement
samples. Of 537 samples with movement input and positive health, 11 had less
than 50 horizontal units of displacement. There were 299 failed route queries
and no logged crashes/script errors. Health alone was an imperfect alive-state
proxy in that old log. These figures show local route trouble, not a precise
measure of how well the bots coordinated.

## v12 — coordination and observer

Adds soft, team-local pursuit claims, target continuity, immediate-threat
priority, and light teammate separation for pilot deathmatch. Claims expire
or clear on death and reset per map. It never excludes the only enemy. Titan
controls keep their prior selection path. A disabled-convar comparison uses
the original target selector.

Adds structured two-second snapshots, native alive/team/Titan information,
target identity/visibility, target switches, path requests/failures, recovery
events, jump commands, turn travel, and spacing counters. A local exporter
produces CSV/JSON and a standalone replay. Seventeen regression tests pass.
The isolated enabled/disabled runs each spawned 15 bots on Relic and another
15 after changing to Wargames, with no logged script errors, access violations
or panics. The Relic enabled run showed fewer target switches and low-movement
samples; see RESULTS-v12.md for counts and comparison limits. The DLL was
installed in the regular and everyday solo profiles, with coordination and
two-second snapshots enabled in the solo preset. A visible Glitch handoff
match was opened for a third-map check.
