# Titanfall 2 solo Northstar project

BT-7274's bot development, custom add-ons, stability fixes, experiments, test
automation and research notebook. This repository preserves the original
[catornot/bp-ort](https://github.com/catornot/bp-ort) Git history and adds our
local work. [Original README](docs/UPSTREAM-README.md).

## Current state

- **Installed for playtesting:** Windows-tested v20 candidate,8v8 (human+15 bots),
  aim0.78. The usual solo shortcut selects Movement (movement/proximity fixes).
  `Play-Solo-Bots.cmd full` selects the broader height/roster/skills/personality
  trial. Aim, firing warm-up, damage and human buffs are preserved.
  [Validation, presets and rollback](Notes/candidates/bot-capability-v20-20261027/README.md).
- **Weapon notebook:** the solo shortcut automatically records local pilot
  damage/life/kill notes. Includes a 30-weapon reference catalog and conditional
  ideal TTK models; observed damage-to-death spans remain separate.
  [How to use it and measurement limits](Notes/weapon-notebook/README.md).
- **First played-session review:** four maps,533pilot death records and128
  qualifying health episodes. War Games recorded33human pilot kills/6deaths.
  Passive/blocked combat movement and unused default tacticals are the strongest
  follow-ups; aim and weapon damage remain unchanged.
  [Findings](research/played-weapons-20261026/FINDINGS.md).
- **Current source:** retains the v18 decision fixes and adds five missing
  standard weapon profiles.46 Rust checks,17 Node checks, the existing-controller
  comparison,11-gun runtime matrix and human stat/stacking/lifecycle checks pass.
  [Current rollout](Notes/candidates/weapons-v19-20261026/README.md).
- **Custom add-ons:** named loadout/basic progress persistence,50% shorter
  human tactical recharge,10% shorter human reloads on G2/Volt/Alternator/R-201/CAR.
  The correction keeps Volt's existing modifier and includes the real Alternator.
  Human-only ADS and four-gun role trials are enabled; bot opt-in remains off.
- **Map survey complete:** all22supported maps have valid16-bot8v8 rounds.
  Three used the200-point goal;19used75points per team. A host cleanup race
  stopped the overnight run; Traffic was recovered and the last two maps
  finished October26. No script/native error was detected in the completed
  round logs. [Findings and evidence](research/maps-v18-20261026/FINDINGS.md).
  War Games/Eden are the strongest route follow-ups. Historical v16/played
  sessions, short/long goals and observer configurations remain separate.

- **New source candidate, not installed:** bot capability v20 — seven default-off
  switches (navigation diagnostics, route guard, jump timing, proximity and
  perception fixes, combat movement, stall-triggered crouch with engine hulls).
  [Switches, evidence, runtime protocol and rollback](research/bot-capability-20261027/README.md).

- **Balance candidate, not installed:** target ~3:1 K/D (baseline 9.7). Height
  response, defensive tactics and a symmetric bot roster, all default off.
  [Plan and levers](research/bot-balance-20261027/README.md).

Read [project status](docs/PROJECT-STATUS.md), [handoff](Notes/HANDOFF.md), and
[the map review](research/trends-20261025/FINDINGS.md) and
[the deeper decision review](research/decision-context-20261025/FINDINGS.md) before changes.

## Contents

| Location | Purpose |
|---|---|
| Rust workspace crates | Native bot/plugin source and upstream experimental tools |
| `tests/` | Native-independent regression tests |
| `BT7274.BotLifecycle/` | Normal solo bot startup |
| `BT7274.BotDecisions/` | Native readiness and hotdrop-state bridge |
| `BT7274.LocalPersistence/` | Saved loadouts/basic XP and UI cache repair |
| `BT7274.TacticalRecharge/`, `BT7274.WeaponReload/` | Human tactical/reload adjustments |
| `BT7274.WeaponHandling/`, `Solo.WeaponBalance/` | Runtime-field-verified human ADS/role trials |
| `research/weapon-roles-20261026/` | Thirty-weapon reference statistics and role hypotheses |
| `Notes/` | Dated notes, results, failures, rollback records and tools |
| `Notes/weapon-notebook/`, `Solo.WeaponNotes/` | Reference catalog, recording methods, validation and read-only telemetry |
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

Validated toolchain: `nightly-2025-09-11-x86_64-pc-windows-gnu` and LLVM-MinGW.
With the toolchain installed and LLVM-MinGW's bin directory on PATH:

```powershell
$env:RUSTUP_TOOLCHAIN='nightly-2025-09-11-x86_64-pc-windows-gnu'
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
