# Map context collected 2026-10-25

These files give us actual navigation surfaces in the same world coordinates
as the bot logs. They are decoded offline from installed meshes, with no
game, native DLL or navmesh changes.

| Map | Installed small-hull surface polygons | Output |
|---|---:|---|
| Eden | 4854 | mp_eden_small/overview.png, hotspot.png |
| Glitch | 1728 | mp_glitch_small/overview.png |
| Angel City | 3666 | mp_angel_city_small/overview.png |

Each folder contains source hashes, validated format/count metadata and
surface-polygons.json. The reader accepts MSET v5 / DNAV v13 and checks tile
sizes, vertex counts/indices and coordinate bounds. Remaining file bytes are
reported, not decoded; adjacency, off-mesh connections and reachability
tables have NOT been reconstructed. Installed hull names are preserved.
The native engine chooses the hull index; do not assume a particular file
is the active query merely from its name without confirming that mapping.

Eden's red points are the 306 stalled pilot samples from the completed fresh
control (161–145,891.5s). They are two-second observations, not306 separate
incidents. Glitch and Angel City currently have geometry only, with no match
observations overlaid. Brighter surfaces represent higher Z; overlapping
floors in the top-down view remain ambiguous.

At exact XY(4120,-355), this decoded small-hull mesh contains a surface near
Z405.76. The earlier FX error's player was nearZ126. This does not establish
the selected polygon, collision geometry, or a broken mesh; nearby lower
surfaces may be used by the live nearest-poly query. It is a reason to inspect
the local height transitions and active hull before changing movement.

## Source-code leads to verify after the frozen tests

- bp_ort/src/bots/cmds_utils.rs consumes route waypoints within45 horizontal
  units using distance(), which ignoresZ (definition near448). A point
  directly above a bot can therefore count as reached. This is a plausible
  level-transition failure mode, not yet a confirmed cause at this hotspot.
- navmesh/navigation.rs projects target goals using extents200,200,500;
  a broad vertical search can involve nearby floors. Need log selected
  start/end polygons and actual route nodes before drawing a conclusion.
- The route generator records straight-path jump/flag arrays, while movement
  follows positions with a height-triggered jump pulse. Confirm whether a
  troublesome route requires a traversal the controller cannot execute.

Do not change these while the v16 comparison queue is running. First compare
the repeat Eden, Glitch and Angel City recordings. A fresh Eden success does
not prove cross-map carryover caused the prior600-FX-handle error.

## Primary references

- [Northstar navigation repository](https://github.com/R2Northstar/NorthstarNavs)
  includes mesh status notes and links to the export/editor tools. Its roof
  and hull restrictions describe intended NPC navigation; they do not prove
  this pilot bot controller can traverse every route.
- [Titanfall Recast editor source](https://github.com/r-ex/r2recast)
- [Map geometry exporter source](https://gist.github.com/warmist/c9efdd4d84f8f97aff806fdbb3853ac8)
- [Navigation tooling author's explanation](https://www.kawe-dev.com/navmesh-tooling)
- Local binary-layout reference:
  C:/Users/james/bp-ort-fork/bp_ort/src/navmesh/bindings.rs

The extraction tool is ../tools/Export-NavMeshContext.ps1. Full scenery/collision
geometry from the packaged BSPs has not yet been exported. No live visual
watching or video capture is claimed by these artifacts.

Follow-up: ../REVIEW-20261025-NAVIGATION.md corrects enemy-height versus waypoint-height interpretation, documents the repeated low waypoint route at the Eden hotspot, and links static engine hull evidence. Actual next-point observations do not establish the vertical-skip hypothesis. The active fresh batch's analysis folder now receives per-map motion reports and stall overlays automatically.
