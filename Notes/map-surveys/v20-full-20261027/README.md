# Unattended Full v20 survey — October 27

BT-7274 authorized collecting more map data overnight while the draft v21 build
files await antivirus review. This runs the already-installed, validated v20
DLL and bridge 1.0.0. No compiler, restored build helper or draft safety script
is used. Normal gameplay settings and saves remain untouched.

Fresh cohort: all 22 supported maps, 75 team points, 15-minute map limit,
16 bots (8 per team) plus inactive human observer. Full v20 enables movement,
proximity, height response, eight-gun roster, skill/defensive policy and weapon
personalities. Aim 0.78 and existing weapon stats retained. Route guard, jump
timing, crouch, perception and the unbuilt v21 switches remain off.

Native SHA256: 3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89.
Bridge SHA256: 9C43719868D28121E6D59A07C3317882E135A50FF3C91AA1340A12C1219C4598.
Core 1.31.14. Existing roster 0.1.1 and WeaponNotes 1.1.1 enabled in isolation.

The runner checks the installed v20 validation receipt and exact DLL/bridge/core
before starting, and freezes runtime hashes across maps. v18 integration gates
remain unchanged for historical runs. Eight process-cleanup and six planning
regression checks passed. The queue retries map failures once, preserves every
attempt, and stops on integrity, ownership or profile-restoration failures.
There are per-map startup/progress/time watchdogs and a process-scoped sleep
prevention guard. No GPU/frame-rate or perceived human difficulty claim follows
from an unattended cohort.

Live receipt: repo-relative `target/v20-overnight-session.json` (private).
Current batch: private audit parent
`Notes/map-surveys/v20-full-overnight-20261027-212916`.
The initial non-desktop launch is retained separately as an invalid startup
attempt in `v20-full-overnight-20261027-212653`; it is not match evidence.
Current deployment/save backup: `Notes/backups/before-v20-full-survey-20261027-212652`.
The isolated profile was set to Full before the queue's per-map backups. Each
child restores that isolated idle config/enablement; original pre-survey settings
are in the named backup. Never restore old save files over later play.

Raw logs retain pilot damage/life/death, skill requests/readiness, weapon,
movement and navigation diagnostics. These are text observations, not video,
throw counts, confirmed ability casts or accuracy. Fresh-process rounds and
bot-only results must stay separate from played v20, v19 and v18 data.
Only sanitized derived summaries may be published.

To stop cleanly, create `stop-after-current.txt` in the CURRENT batch from the
live receipt. It finishes the current child before stopping. Do not overwrite
profile files or terminate a child while it owns the loaded game. Completion
and failures are in batch `status.json`, `coverage.json` and `summary.json`.
