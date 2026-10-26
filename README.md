# Titanfall 2 solo Northstar project

James's bot development, custom add-ons, stability fixes, experiments, test
automation and research notebook. This repository preserves the original
[catornot/bp-ort](https://github.com/catornot/bp-ort) Git history and adds our
local work. [Original README](docs/UPSTREAM-README.md).

## Current state

- **Installed:** tested decisions-v18-candidate,8v8 (human+15 bots), aim0.78.
- **Current source:** navigation watchdog context, hotdropping-pet targeting,
  readiness-gated offhand inputs and safe opposite-side combat stepping.
  41 offline tests, a47058-decision controller comparison, full client/map/lobby
  checks and a final mixed-loadout readiness retest pass.
  [Candidate record](Notes/candidates/decisions-v18-20261025/README.md).
- **Custom add-ons:** named loadout/basic progress persistence,50% shorter
  human tactical recharge,10% shorter human reloads on G2/Volt/R-201/CAR in
  the tested installation. The prior notes misidentified Volt as Alternator;
  source candidate1.0.1 adds the actual Alternator, pending runtime validation.
- **Map survey complete:** all22supported maps have valid16-bot8v8 rounds.
  Three used the200-point goal;19used75points per team. A host cleanup race
  stopped the overnight run; Traffic was recovered and the last two maps
  finished October26. No script/native error was detected in the completed
  round logs. [Findings and evidence](research/maps-v18-20261026/FINDINGS.md).
  War Games/Eden are the strongest route follow-ups. Historical v16/played
  sessions, short/long goals and observer configurations remain separate.

Read [project status](docs/PROJECT-STATUS.md), [handoff](Notes/HANDOFF.md), and
[the map review](research/trends-20261025/FINDINGS.md) and
[the deeper decision review](research/decision-context-20261025/FINDINGS.md) before changes.

## Contents

| Location | Purpose |
|---|---|
| Rust workspace crates | Native bot/plugin source and upstream experimental tools |
| `tests/` | Native-independent regression tests |
| `James.BotLifecycle/` | Normal solo bot startup |
| `James.BotDecisions/` | Native readiness and hotdrop-state bridge |
| `James.LocalPersistence/` | Saved loadouts/basic XP and UI cache repair |
| `James.TacticalRecharge/`, `James.WeaponReload/` | Human tactical/reload adjustments |
| `Notes/` | Dated notes, results, failures, rollback records and tools |
| `Notes/map-surveys/` | Per-match movement/combat data and restoration checks |
| `Notes/trend-analysis-20261025/` | Latest played-session export |
| `research/trends-20261025/` | Phase-aware trends and improvement priorities |
| `research/decision-context-20261025/` | Deduplicated descending-target observations and watchdog context |
| `research/weapons-abilities-20261025/` | Weapon coverage, verified human modifiers and bot ability decision audit |
| `Notes/map-context/` | Derived navigation geometry, diagrams and references |
| `automation/runtime-mods/` | Isolated authored harnesses; **not gameplay add-ons** |
| `automation/legacy/` | Original machine-specific launch/audit scripts |
| `history/source-snapshots/` | Expanded historical source, including rejected experiments |
| `tools/` | Import, artifact extraction and offline checks |

## Build and check

Validated toolchain: 
ightly-2025-09-11-x86_64-pc-windows-gnu` and LLVM-MinGW.
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
unattended cohorts differ. The trend report trims intros/post-match time;
older full-session exports remain intact. Bot weapon evidence is
mostly R-201 in the historical survey. The new isolated integration matrix
observed six gun classes and seven suits, but is not a balance study. Default
bot loadouts remain Grapple/frag; Grapple/A-Wall automation is not implemented.

Sanitized logs are stored as `.log.gz`; expand a selected file with
`tools/Expand-ResearchLog.ps1`. Replays and derived JSON/CSV/PNG are retained.
Authentication material and personal saved state are excluded. Game packages,
installed third-party bundles, dump/build binaries and private backup saves
remain local. [The import manifest](docs/LOCAL-IMPORT-MANIFEST.json) records
included/excluded artifacts and hashes. [Data provenance](docs/DATA-PROVENANCE.md)
explains sanitization and line-ending/hash differences. No local backup was deleted.

Upstream release/deployment workflows are archived under `docs/upstream-workflows`
with `.disabled` suffixes; this import does not publish releases or change the game.

## License

Upstream native code is Apache-2.0; [LICENSE](LICENSE) and Git history are
retained. [NOTICE](NOTICE) records provenance. Extracted game resources and
installed third-party distributions are not licensed or supplied by this repo.
