# Project instructions

Canonical development repo for BT-7274's solo Northstar project. Read README.md,
docs/PROJECT-STATUS.md, Notes/CURRENT-SETUP.md and the latest Notes/HANDOFF.md
entries before changes.

- Refer to the owner only as BT-7274 (prose) / BT7274 (identifiers) in every
  file, filename and commit message; never by a personal name. See
  docs/BT7274-RENAME.md before deploying renamed add-ons (profiles need
  tools/Migrate-BT7274Rename.ps1 so saves keep working).

- User authorized implementing and testing the reviewed changes on2026-10-25.
  Use backed-up candidates and isolated runtime/transition tests before normal
  deployment. User also authorized resuming map-by-map testing AFTER those
  checks; start a fresh frozen-build survey rather than changing old cohorts.
- Normal and working isolated profiles now use the Windows-tested v20 candidate,
  DLL3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89.
  Normal launcher defaults to Movement (movement+proximity, diagnostics/sampler).
  Height/Roster/Skills/Full are explicit cumulative playtest presets. Crouch,
  route/jump and perception remain OFF. Read Notes/candidates/bot-capability-v20-20261027.
  Eight-gun/six-tactical readback,32human modifier checks, cancellation restore,
  lobby/map changes, live v19 rollback and normal startup passed. The fresh candidate clone
  remains startup-broken and is abandoned; use map-cycle-test-profile for tests.
  Verify actual hashes/logs before further claims. All four new switches are on.
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
- Latest played review:research/played-weapons-20261026/FINDINGS.md. Four maps,
  533pilot deaths,128qualifying episodes;33/6recorded human pilot K/D on WarGames.
  Counts exclude Titan victims and are not scoreboards. Grounded combat-step
  alternatives/blocked holds are installed as the Movement playtest; map-cell
  recovery remains a separate follow-up.
  Preserve aim0.78 and existing0.8sfiring warm-up; user explicitly dislikes
  instant/unfair bot shooting. No damage/reaction buff justified by this cohort.
  Default Grapple/frag still unused; any defensive-tactical mix needs a separate
  backed-up isolated trial. Do not confuse this played v19 session with v18survey.
