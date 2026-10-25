# Decision-context analysis methods

This is an offline analysis of existing v16 data, not a gameplay experiment.
The game, installed profiles, saves and paused map queue are untouched.

## Reproduce

Requires Node.js 22 (no packages). From the repository root:

```powershell
node tools/Analyze-DecisionContext.mjs --self-test
node tools/Analyze-DecisionContext.mjs
```

If Windows sandbox parent-directory traversal prevents Node's entry-point
realpath check, use `node --preserve-symlinks --preserve-symlinks-main` in both
commands. This was required in the current sandbox. No elevation is needed.

The input index is [the phase-aware round list](../trends-20261025/rounds.json).
It supplies 16 recordings and their existing epoch/time windows. The tool
requires v16 metadata and checks every round's overhead snapshot count against
that independent PowerShell builder. Played rounds exclude lobby/intro/post-match
using the previously derived approximate playing/completion boundaries. Controlled
rounds retain their published trial windows; partial Kodai stays a separate cohort.

[Provenance](provenance.json) hashes the tool, index, input files, relevant native
source and research reproduction. Text hashes normalize CRLF to LF, matching
repository text policy and avoiding differences between existing Windows import
copies and fresh clones. Gzip hashes use exact binary bytes. These identify the
sanitized repository content, not pre-import private files. JSON/CSV exports
retain source-relative paths and per-round identity. No external downloads or
private saved state are used.

The current diagnostic-v17 source's watchdog and cmds_utils files, and its
find_team_target function, were compared to the archived v16 source with line
endings normalized: identical. The source explanations therefore apply to the
recorded v16 behavior. [Verification record](verification.json).

## Overhead selection

An overhead bot snapshot is an alive bot pilot, `engage`, `visible=1`, a valid
selected target, and `target_z - pilot_z > 5000`. This is a diagnostic threshold,
not a proposed gameplay cutoff. It does not establish a fired shot or wasted ammo.

Group all live bots' target coordinates by entity handle and frame time within
one recording/epoch. Use median target Z and retain the same-frame Z spread.
Several bots viewing one target at one time become one target/time observation.
A burst consists of successive overhead target frames with gaps at most 2.1s;
an intervening observed frame with no overhead pilot engagement ends it. A gap
also ends it. This counts selection bursts, not independent Titan spawns.

Inspect adjacent coordinates within the burst and at its immediately following
target observation, if within 2.1s. `observed_drop_ge500` means at least one such
pair decreases target Z by at least 500 units. Single observations without a
following adjacent sample are unclassified, not stationary-target evidence.
The tool does not interpolate across gaps or beyond a round boundary.

Join handles to alive BOT_PLAYER entities at the exact same frame. A missing
match means only that the selected entity was absent from the player list.
It does not prove NPC class, Titan class or transit state. No join to script
kill handles is attempted because their identifier namespace is unverified.

One/two sampled high frames have observed spans of zero/two seconds. Actual
duration can begin before and end after those frames, and target selection
may change between them. These are not measured fixation durations.

## Movement recovery context

Only explicit `BOT_RECOVERY` events are counted, retaining their reason.
Some obstacle avoidance does not emit this event. Event totals include pilot,
Titan and unclassified contexts; they are not a pilot false-alarm denominator.

For each event, use strictly preceding snapshots of that bot slot. Exclude
same-time BOT_TRACE because it can be emitted after the recovery. Require:

- Three alive pilot snapshots with the same entity handle, spanning at least
  3.9s and with adjacent gaps at most 2.1s.
- All three are visible engagement; maximum pairwise XY displacement is below
  50 units. Event position is within 80 XY units of the last snapshot.
- Path-request and recovery counters are constant across those three snapshots.
- The event is `no_progress`; no previous explicit recovery occurred within 4s.

Report separate frame-age thresholds of <=0.25s, <=0.5s and <=2.1s. These are
**possible stale navigation-anchor contexts**, not confirmed false recoveries.
Two-second snapshots miss intervening pursuit, death/respawn and movement;
constant path requests do not rule out following an existing path. The strict
filter is intentionally narrow and does not estimate overall prevalence.

[Strict examples](strict-recovery-examples.json) contain the original sanitized
BOT_PLAYER/TRACE/DECISION/RECOVERY lines around the five <=0.25s cases. No
unrelated log text, authentication data or personal saves are copied.

## Source reproduction

[watchdog-repro.rs](watchdog-repro.rs) imports the actual current watchdog helper.
It calls it once, leaves a four-second gap without path-following calls, then
calls it at the same position. Compare fresh-anchor, moved-position and genuine
continuous-navigation stall cases. It does not simulate engine movement or
prove the exact command sequence in a recorded match.

```powershell
New-Item -ItemType Directory -Path target/offline-checks -Force | Out-Null
rustc +nightly-2025-09-11-x86_64-pc-windows-gnu --edition 2024 research/decision-context-20261025/watchdog-repro.rs -o target/offline-checks/watchdog-context-repro.exe
./target/offline-checks/watchdog-context-repro.exe
```

LLVM-MinGW's bin directory must be on PATH for this validated Windows GNU
toolchain. [Recorded output](watchdog-repro-result.json) describes current
behavior. This executable is local/ignored and never deployed or published.

Fixtures exercise CSV quoting/newlines, multi-bot deduplication, temporal gaps,
player-entity matching, strictly preceding event context, intervening pursuit,
entity/death/Titan boundaries, recent recoveries and changed path counters.
No production native code was changed, so this pass did not rebuild/deploy the
plugin or rerun unrelated gameplay regression suites.
