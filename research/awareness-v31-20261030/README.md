## Current status — held for antivirus review

The four-hour run has NOT started. User reported Bitdefender flags naming
pwsh.exe. Exact detection and command line pending. Installed PowerShell host
has a valid Microsoft Corporation Authenticode signature; that does not establish
safety of the executed command or rule out a script/behavior detection.
No exclusions, quarantine restoration or antivirus changes. Initial CE1369...
five-phase lifecycle passed; revised522A8B...compiled but its lifecycle was NOT
started. Normal12fileguard unchanged, isolated native307...restored, no game or
build running. Do not run the coordinator or resume old receipts while this is
unresolved. Deadline below is historical authorization, not a fresh run request.
Private target/v31-active-session.json records this hold.134Rust tests/23suites,
PS migration/preset checks and121Node tests/24files passed before the hold.
# Awareness v31 — bounded exploratory trial

BT-7274 authorized four hours of unattended iterative tests on2026-10-30.
Deadline2026-10-31 01:47EDT. Current private coordinator receipt is integration
`target/v31-active-session.json`; inspect real state, never resume old PIDs.
Normal play native/saves/settings including75%bot frag self-damage reduction are
guarded and unchanged. No automatic normal deployment.

New default-off bot_fair_awareness applies to pilot mode6 only. It filters legacy
selection through per-bot knowledge: only a confirmed visible selected enemy
updates memory, unseen goals remain at last-seen coordinates, entry expires
(default4s, clamped1..12), reaching within100XY/100Z searches briefly1.5s, then
forgets. Maximum8observations; dead/invalid targets and time rollback removed.
No sound/radar/team-sharing implementation is claimed. Titans and objective
modes retain baseline selection. Old visibility tests still define an observation;
this does not establish Cloak/Pulse fairness or human difficulty.

Without a remembered target, pilot patrol samples navmesh points around itself
(radius1800, bounded4queries,2s retry/8s goal lifetime). It never uses an enemy
origin for patrol. Visible shooting/aim/warm-up unchanged. Candidate state resets
through existing per-life/Titan lifecycle; off restores selection. Existing v29
escape/crouch and rejected route trials remain off. Grenade self-damage scale0.25
is identical in every cell. Low-progress review now includes patrol states.

Initial native CE1369... lifecycle remains separate. Follow-up native522A8B...
adds explicit observation timestamps in logs and avoids clearing route state on
mere visibility flicker. It clears on patrol/target handoff and preserves normal
recalc on target changes. Safety lifecycle is rerun on that frozen final native.
No mesh or ABI changes.134Rust tests/23suites and migration/preset fixtures
passed; Node regression status and final lifecycle recorded separately.

After final off/on/respawn/off/lobby/new-map gate, fresh-process50-goal Full16bot
observer matches compare baseline vs memory4 first, on Glitch/Drydock/WarGames/
Complex initially; repeats add Relic/Colony/AngelCity/Kodai. Later cells test2s/6s memory and a separate
4s+existing eye-level/facing correction. Cell order reverses by cycle/map.
After screening, repeats select closeness to control activity plus a low-progress
penalty; this is operational exploration, not optimization of human fairness.
Every round is analyzed before the next; severe stalls/activity regression
disables that cell. Native/code stay frozen. No mid-match edits.12-minute margin
before deadline,15-minute round wall watchdog,4-minute heartbeat. Automatic
owned-process shutdown and isolated profile rollback; never old-save restoration.

Metrics: actual score/duration, patrol/navigation samples, damage/weapon/frag
observations, explicit frozen-observation comparisons. They are exploratory,
not randomized causal outcomes. Mode log counts are transitions/spaced samples,
not durations. Clockless notebook gaps remain flagged. No video watching occurs.
Human stealth/reacquisition feedback is still required before normal deployment.

Raw logs, handles, account data, saves and DLLs remain private. Public status.json
contains sanitized aggregates only and will change during the background run.
