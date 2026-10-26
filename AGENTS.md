# Project instructions

Canonical development repo for James's solo Northstar project. Read README.md,
docs/PROJECT-STATUS.md, Notes/CURRENT-SETUP.md and the latest Notes/HANDOFF.md
entries before changes.

- User authorized implementing and testing the reviewed changes on2026-10-25.
  Use backed-up candidates and isolated runtime/transition tests before normal
  deployment. User also authorized resuming map-by-map testing AFTER those
  checks; start a fresh frozen-build survey rather than changing old cohorts.
- Normal and working isolated profiles now use tested decisions-v18-candidate,
  DLL F3C41DE2D11C84959454A16C8DCE9ED8B03BCD5E05E59090E32E87C6B78F3648.
  Full client suite and final readiness retest passed. The fresh candidate clone
  remains startup-broken and is abandoned; use map-cycle-test-profile for tests.
  Verify actual hashes/logs before further claims. All four new switches are on.
- Preserve8v8, aim0.78, current saves,50% human tactical recharge and the
  existing four-gun human reload change unless asked to change them.
- Preserve two-buffer pathfinder and map-teardown fixes. Rejectedv13 raw
  persistence andv14 route/cache experiments are historical, not approved.
- Back up CURRENT deployment files/saves. Never restore old survey saves
  over new play. No raw persistence buffers or routine ns_resetpersistence.
- Keep played/unattended/partial/different-build cohorts separate. Samples
  are not video, independent incidents, simultaneous visibility or proven harm.
- No live visual watching occurred. Capture helper was unavailable; do not
  claim spectator video from telemetry. No recorder has been installed.
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
- Default bots still use Grapple/frag, which lack legacy activation requests.
  Mixed suits/weapons are test-only. Do not claim Grapple/A-Wall automation or
  improved damage/win rate from readiness/pulse diagnostics.
- The22-map survey is COMPLETE as of2026-10-26:3prior200-goal matches and19at75.
  Overnight host cleanup raced a natural exit; Traffic was recovered from a
  clean completed log, then UMA/Coliseum finished today. No queue/game remains.
  Read research/maps-v18-20261026/FINDINGS.md and latest handoff; old PIDs/status
  are historical. Native/ability hashes unchanged. Cleanup regression fixtures
  cover the race and exact process ownership. Failed attempts stay failures.
