# Native traversal link codes — evidence and experiment (2026-10-29)

This source-only pass identifies the native interfaces for Titanfall 2's pilot navigation. It **does not** infer a slide, jump, climb, wall-run or Grapple action from a raw byte and does not change pilot input. All diagnostics remain gated behind the existing default-off `bot_nav_diagnostics 1` switch. It preserves the previous verified backup, two-buffer native pathfinder, map teardown and normal install.

## Interface evidence

| Evidence | Established | Not established |
| --- | --- | --- |
| `bp_ort/src/navmesh/mod.rs` `JumpTypes` enum | 21 named values represented as *bits* of a `u32` traversal filter | That a returned one-byte corner `jump` value is the same ordinal or mask |
| `Navigation::new(Hull::Human)` `dtQueryFilter.m_traverseFlags` | Currently enables SmallObjectsCrossing, CratesTraversal, ShortWallTraversal, and ShortJumpsAcrossSameLevel | That a pilot can execute those traversals merely by running forward |
| `Navigation::new_path` | Calls Titanfall-specific `findPath` with separate polygon and jump-type output buffers and passes both into `findStraightPath`; preserves raw `straightPathFlags` and `straightPathJumps` per point | The semantics of any nonzero Titanfall jump byte, including `255` |
| Standard Recast/Detour straight-path flags | `0x01` START, `0x02` END, `0x04` OFFMESH; the last denotes the start of an off-mesh connection in standard Detour | Whether a special jump byte indicates slide, grapple or wall-running |
| R2Northstar/NorthstarNavs map notes | Many navmeshes deliberately remove roofs; its authors explicitly note unresolved jump points; Eden is classified “Very Good” as a mesh, not validated pilot traversal | That the present bot's Eden stalls are caused only by mesh geometry or any one link type |

Sources:
- Upstream Recast/Detour flags: https://github.com/recastnavigation/recastnavigation/blob/main/Detour/Include/DetourNavMesh.h
- Upstream straight-path interface: https://github.com/recastnavigation/recastnavigation/blob/main/Detour/Include/DetourNavMeshQuery.h
- Titanfall navmesh context: https://github.com/R2Northstar/NorthstarNavs
- Native bindings in this repository: `bp_ort/src/navmesh/mod.rs`, `bp_ort/src/navmesh/navigation.rs`, and `bp_ort/src/bots/cmds_utils.rs`.

## Diagnostic-only classification

`BOT_CORNER` logs a proposed route corner, with **raw** `flags` and `jump` and a non-authoritative class label. `BOT_STALL` records the **last-known** current-corner raw metadata; after replanning, that metadata is cleared rather than reused. Both emit classes using these ordered rules:

| Class | Rule | Action policy |
| --- | --- | --- |
| `missing` | No aligned corner metadata | Do not assume ordinary movement |
| `unknown_flags` | Bits beyond standard `0x01/0x02/0x04` | No automatic action |
| `offmesh_flag` | `0x04` present | Standard Detour off-mesh *flag*, Titanfall execution unverified |
| `unknown_jump` | Jump byte `255`, no offmesh bit | Treat as unknown/sentinel; no automatic action |
| `coded_jump` | Other nonzero jump byte, no offmesh bit | Record code; no action mapping yet |
| `ordinary_candidate` | No unexpected flags and jump byte is zero | A candidate ordinary corner, not proof of clearance |

The optional `bot_low_clearance_approach` controller now also rejects **unknown flag bits** (as well as missing metadata, off-mesh bits and nonzero jump codes). This is a fail-closed fix to the previous check which excluded only the off-mesh bit.

## Offline analysis and measurement

`node tools/Analyze-BotAITrial.mjs --log <PRIVATE-NSLOG> --out <PRIVATE-REPORT.json>` groups `BOT_CORNER` and `BOT_STALL` classes by engine epoch/map and includes a bounded **64-pair** histogram of actual `flags:jump` code combinations, with overflow counters. Output strips player identifiers, targets and coordinates. The counters are descriptive logged samples, **not** per-link traversal success or causal failure rates; BOT_STALL can refer to a last-known waypoint. The analyzer uses raw bytes rather than trusting the source's class label.

Run isolated matched sessions with `bot_nav_diagnostics 1` on Eden, War Games, Complex and Meadow, first with all new movement switches off, then one behavior switch at a time. Review any common nonzero jump codes alongside physical obstacle location, engine traces and visual observation; separately validate an actual crouch/slide/wall-run action before mapping a code to behavior. If a code is map-dependent or ambiguous, keep it unknown and prioritize replanning/avoidance instead. Measure CPU/p95 overhead from diagnostics before wider adoption.

## Validation status

Added Rust pure-classification unit assertions and Node analyzer fixtures. Node tests may be run locally without the game. The native compiler, Windows distribution DLL and played-match validation remain separate prerequisites. No deployed behavior, saves or navmeshes were modified.
