# Project instructions

Canonical development repo for BT-7274's solo Northstar project. Read README.md,
docs/PROJECT-STATUS.md, Notes/CURRENT-SETUP.md and the latest Notes/HANDOFF.md
entries before changes.

- Current October29 four-hour TEST ONLY: integration-v28 worktree/branch;
  receipt target/v28-study-resumed-session.json THERE; deadline16:27:48EDT.
  Read actual status before any launch. Freeze active tools/analysis/cell config.
  Normal remains v23BC2...; no automatic promotion. See latest handoff.
- October29 current research: normal remains v23BC2... unchanged. Separate
  candidate/traversal-v26-20261029 prototype passed lifecycle but NOT effectiveness;
  no rollout. Latest frozen map study receipt is target/v24-study-after-v26-session.json,
  deadline08:03EDTOct29. Read actual status/clock before acting; never resume old
  PIDs automatically. See latest handoff and research/routing-v24-20261029.
- Current normal deployment is the tested v23 Eden pilot route repair:
  BC2C1019D27F537F075611ED6B68A75591D1F2F9924BA8700D82A757BB1000F7.
  bot_eden_route_repair=1; global route_continuity/link_detour and corner-height
  switches stay0. Other maps and Titan navigation retain baseline behavior.
  Read research/route-continuity-v23-20261028/FINDINGS.md and validation.json.
  The repeated directed hotspot test, off/on/respawn/off/lobby/Complex transition
  and effective map-scope checks passed. Six normal saves and enabledmods were
  hash-preserved; existing gameplay settings unchanged. Same solo shortcut.
  Isolated profile restored to v20 native3077878B...; all harnesses disabled.
  No game remains. target/v23-eden-repair-session.json is historical evidence,
  not an instruction to resume it. New combat/human validation is still needed
  before extending the repair to other maps or link types.
- The earlier four-hour v22 matrix FINISHED29/32rounds,14pairs with mixed results.
  Keep its height guardOFF; do not resume old queues/PIDs. v21 safety/retarget
  trials stayOFF. Use pinned release-debug/offline builds with antivirus enabled.
  Do not alter antivirus/quarantine or run/stage Build-VerifiedWindowsCandidate.ps1.

- Refer to the owner only as BT-7274 (prose) / BT7274 (identifiers) in every
  file, filename and commit message; never by a personal name. See
  docs/BT7274-RENAME.md before deploying renamed add-ons (profiles need
  tools/Migrate-BT7274Rename.ps1 so saves keep working).

- User authorized implementing and testing the reviewed changes on2026-10-25.
  Use backed-up candidates and isolated runtime/transition tests before normal
  deployment. User also authorized resuming map-by-map testing AFTER those
  checks; start a fresh frozen-build survey rather than changing old cohorts.
- The v20 foundation and isolated rollback DLL is
  DLL3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89.
  Normal launcher defaults to Movement (movement+proximity, diagnostics/sampler).
  Height/Roster/Skills/Full are explicit cumulative playtest presets. Crouch,
  global route/jump and perception remain OFF; the Eden-only repair is separate.
  Read Notes/candidates/bot-capability-v20-20261027 for the foundation checks.
  Eight-gun/six-tactical readback,32human modifier checks, cancellation restore,
  lobby/map changes, live v19 rollback and normal startup passed. The fresh candidate clone
  remains startup-broken and is abandoned; use map-cycle-test-profile for tests.
  Verify actual hashes/logs before further claims; preserve current preset selection.
- Preserve8v8, aim0.78, current saves,50% human tactical recharge and the
  five-gun human reload change (G2/Volt/Alternator/R201/CAR). Human ADS and
  role trials are enabled; solo_weapon_balance_bots stays0. See latest rollout.
- Preserve two-buffer pathfinder and map-teardown fixes. Rejectedv13 raw
  persistence andv14 route/cache experiments are historical, not approved.
- Back up CURRENT deployment files/saves. Never restore old survey saves
  over new play. No raw persistence buffers or routine ns_resetpersistence.
- Northstar1.31 Version1 enabledmods MUST disable per-version entries, not a
  bare false (loader auto-enables that). Use tools/Northstar-ModState.ps1 in
  migration/rollback; clone version objects before disabling old family.
  Game Assert is inactive in this runtime: test harnesses must throw explicitly.
- Keep played/unattended/partial/different-build cohorts separate. Samples
  are not video, independent incidents, simultaneous visibility or proven harm.
- No live visual watching occurred. Do not claim spectator video from telemetry.
  Solo.WeaponNotes1.1.1 now records TEXT pilot damage/life/death events through
  the solo shortcut; see Notes/weapon-notebook/README.md and VALIDATION.md.
  It measures first-positive-health-damage-to-death, NOT first-shot TTK or
  accuracy. Post-damage callbacks still see old HP: preserve end-of-frame reads,
  overlap exclusions, life/config boundaries and known-modifier requirements.
  Sessions stay private; only reviewed derived aggregates may be published.
- Native candidates require authorized isolated runtime/transition checks,
  movement/combat, population, saves and errors before deployment.
- Keep credentials, personal saves, game assets, installed third-party
  bundles and dumps local. Publish sanitized evidence and manifests.
- Source work belongs here. The old bp-ort-fork remains a rollback/history
  checkout; don't silently build/edit it. tools/Test-Project.ps1 checks HERE.
- Fresh profiles MUST include the matching Northstar.dll, not just mods/plugins.
  Launcher otherwise falls back to the game-root1.30.2 core, incompatible with
  the working1.31.14 mods/versioned enabledmods. Verify actual startup log version.
- Record hashes/deployment states and preserve local edits. No force-pushes
  or resets discarding work. Keep upstream attribution.
- A new22-map v18 cohort was started after validation. Read the latest handoff
  and private current-v18-session/status.json; never infer a live PID from notes.
  Pause with stop-after-current.txt, not by restoring old survey saves.
- Movement/default bots still use Grapple/frag. Roster/Skills/Full opt into
  tested loadout/skill candidates. Grapple traversal remains unimplemented;
  requests/readiness are not confirmed casts or proof of improved win rate.
- The22-map survey is COMPLETE as of2026-10-26:3prior200-goal matches and19at75.
  Overnight host cleanup raced a natural exit; Traffic was recovered from a
  clean completed log, then UMA/Coliseum finished today. No queue/game remains.
  Read research/maps-v18-20261026/FINDINGS.md and latest handoff; old PIDs/status
  are historical. Survey data is frozenv18, NOT the newv19 weapon build. Cleanup regression fixtures
  cover the race and exact process ownership. Failed attempts stay failures.
- User authorized integration/install of all four weapon-work branches.
  Notes/candidates/weapons-v19-20261026/README.md is the current rollout record.
  Keep effective-variable validation distinct from feel/hit-rate/balance proof.
- Latest Full review: research/played-full-v20-20261027/FINDINGS.md. Four rounds,
  646 pilot deaths/96 qualifying episodes; much less stationary combat, but
  103 frag self-kills versus 37 enemy kills. Prioritize isolated grenade
  lifecycle/safety and Eden link recovery; Phase/A-Wall casts unconfirmed.
  Review only, no installed settings changed. Keep aim/damage/warm-up unchanged.
  Whole-log diagnostics and per-played-window diagnostics have different scopes.
- Earlier played review:research/played-weapons-20261026/FINDINGS.md. Four maps,
  533pilot deaths,128qualifying episodes;33/6recorded human pilot K/D on WarGames.
  Counts exclude Titan victims and are not scoreboards. Grounded combat-step
  alternatives/blocked holds are installed as the Movement playtest; map-cell
  recovery remains a separate follow-up.
  Preserve aim0.78 and existing0.8sfiring warm-up; user explicitly dislikes
  instant/unfair bot shooting. No damage/reaction buff justified by this cohort.
  Default Grapple/frag still unused; any defensive-tactical mix needs a separate
  backed-up isolated trial. Do not confuse this played v19 session with v18survey.
