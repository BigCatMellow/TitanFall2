# Titanfall 2 solo Northstar project

James's bot development, custom add-ons, stability fixes, experiments, test
automation and research notebook. This repository preserves the original
[catornot/bp-ort](https://github.com/catornot/bp-ort) Git history and adds our
local work. [Original README](docs/UPSTREAM-README.md).

## Current state

- **Installed and played:** combat-decisions-v16,8v8 (human+15 bots), aim0.78.
- **Current source:** observation-v17-candidate, diagnostics only, **not
  deployed or runtime-tested**.34 offline tests and a47058-decision comparison
  against v16 pass. [Candidate record](Notes/candidates/observation-v17-20261025/README.md).
- **Custom add-ons:** named loadout/basic progress persistence,50% shorter
  human tactical recharge,10% shorter human reloads on G2/Alternator/R-201/CAR.
- **Map survey:** paused by James. Five new full trials plus partial Kodai;
  17 trials remain. Earlier runs provide10 completed recordings on9 maps.
  Newer human-played Eden/Exoplanet data is also retained. No automatic resume.

Read [project status](docs/PROJECT-STATUS.md), [handoff](Notes/HANDOFF.md), and
[the latest review](Notes/review-paused-20261025/REVIEW.md) before changes.

## Contents

| Location | Purpose |
|---|---|
| Rust workspace crates | Native bot/plugin source and upstream experimental tools |
| `tests/` | Native-independent regression tests |
| `James.BotLifecycle/` | Normal solo bot startup |
| `James.LocalPersistence/` | Saved loadouts/basic XP and UI cache repair |
| `James.TacticalRecharge/`, `James.WeaponReload/` | Human tactical/reload adjustments |
| `Notes/` | Dated notes, results, failures, rollback records and tools |
| `Notes/map-surveys/` | Per-match movement/combat data and restoration checks |
| `Notes/trend-analysis-20261025/` | Latest played-session export; cohort review in progress |
| `Notes/map-context/` | Derived navigation geometry, diagrams and references |
| `automation/runtime-mods/` | Isolated authored harnesses; **not gameplay add-ons** |
| `automation/legacy/` | Original machine-specific launch/audit scripts |
| `history/source-snapshots/` | Expanded historical source, including rejected experiments |
| `tools/` | Import, artifact extraction and offline checks |

## Build and check

Validated toolchain: `nightly-2025-09-11-x86_64-pc-windows-gnu` and LLVM-MinGW.
With the toolchain installed and LLVM-MinGW's bin directory on PATH:

```powershell
./tools/Test-Project.ps1
$env:CARGO_PROFILE_DISTRIBUTION_STRIP='none'
$env:CARGO_PROFILE_DISTRIBUTION_DEBUG='2'
cargo +nightly-2025-09-11-x86_64-pc-windows-gnu build -p bp_ort --profile distribution --locked -j 1
```

Output: `target/x86_64-pc-windows-gnu/distribution/bp_ort.dll`. Building does
not install it. Back up deployment files/CURRENT saves and validate a candidate
in an isolated profile, including movement/combat/map transitions, before
deployment. Never copy disposable test loadouts into the normal profile.

Historical tools in `Notes/tools` and `automation/legacy` contain machine-specific
paths; imported account identifiers are replaced with `LOCAL_PLAYER_UID`.
Configure those before use. Existing installed profiles/shortcuts were not moved.

## Data and archives

These are gameplay logs and reconstructed paths, not live visual observation.
Sample counts are not independent incidents or proof of improved AI. Human and
unattended cohorts differ. Intros/post-match windows still need trimming from
some older full-session exports before comparison. Bot weapon evidence is
mostly R-201, not a broad weapon/ability balance study.

Sanitized logs are stored as `.log.gz`; expand a selected file with
`tools/Expand-ResearchLog.ps1`. Replays and derived JSON/CSV/PNG are retained.
Authentication material and personal saved state are excluded. Game packages,
installed third-party bundles, dump/build binaries and private backup saves
remain local. [The import manifest](docs/LOCAL-IMPORT-MANIFEST.json) records
included/excluded artifacts and hashes. No local backup was deleted.

Upstream release/deployment workflows are archived under `docs/upstream-workflows`
with `.disabled` suffixes; this import does not publish releases or change the game.

## License

Upstream native code is Apache-2.0; [LICENSE](LICENSE) and Git history are
retained. [NOTICE](NOTICE) records provenance. Extracted game resources and
installed third-party distributions are not licensed or supplied by this repo.
