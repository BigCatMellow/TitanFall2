# Project instructions

Canonical development repo for James's solo Northstar project. Read README.md,
docs/PROJECT-STATUS.md, Notes/CURRENT-SETUP.md and the latest Notes/HANDOFF.md
entries before changes.

- User paused game/map testing and requested offline organization/trend review.
  Do not launch a game, resume a queue or deploy without later authorization.
- Installed profiles use stablev16. Source/build output is diagnosticv17,
  NOT a deployed gameplay change. Verify actual hashes/logs before claims.
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
- Record hashes/deployment states and preserve local edits. No force-pushes
  or resets discarding work. Keep upstream attribution.
