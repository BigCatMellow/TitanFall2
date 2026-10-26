# Project status — 2026-10-26

The reviewed decision changes are implemented, tested and installed in the
normal solo profile. The22-map survey is now complete; the final two maps were
finished today after fixing an overnight host-cleanup race.
See [candidate record](../Notes/candidates/decisions-v18-20261025/README.md).

| Item | State |
|---|---|
| Installed native plugin | decisions-v18-candidate; all four new switches enabled |
| Native SHA256 | F3C41DE2D11C84959454A16C8DCE9ED8B03BCD5E05E59090E32E87C6B78F3648 |
| Readiness script SHA256 | 30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78 |
| Core runtime | Northstar1.31.14.0, verified in actual test logs |
| Offline validation |41tests/8suites;47058 pure-controller decisions match v16; native build passes |
| Full client integration |Passed progressive switches, five16-bot phases, Eden/Complex/Canal, six guns/seven suits, lobby and human+15bot return |
| Final bridge retest |Passed matrix/lobby/normal return;866cost samples,38unaffordable tactical samples,0incorrectly-ready |
| Normal deployment |19:48EDT; fresh backup; all3current save files hash-unchanged during deployment |
| Preserved settings |8v8 human+15bots, aim0.78,50% human tactical recharge, four-gun0.9reload |
| Survey |22/22supported maps complete:3at200goal,19at75goal;16bots8v8+observer; no detected script/native error in completed round logs |
| Follow-up |War Games7.01%/Eden4.97%continuous low-progress samples; shared route cells recur. Single rounds, overlapping samples, not causal before/after evidence |
| Cleanup |Natural-exit race fixed; Traffic recovered with original failure retained;8cleanup+6planning+4metric fixtures pass |
| Earlier data |16recordings/10maps phase-aware v16 review; kept separate from v18 |

New behavior: clear movement-watchdog context after non-navigation commands;
exclude hotdropping pet Titans before pilot target choice and pursuit; gate
bounded offhand inputs on fresh engine readiness/resource reports; try the
opposite strafe with the same wall/ground checks when the first side is blocked.
Actual current-weapon/action diagnostics supplement the older combat cache.

The full suite sampled11known-hotdrop target selections in baseline and0with
the filter enabled. These are integration observations, not a randomized outcome
comparison. Pulse counters and tactical shot/resource snapshots are not cast
totals. Default bots still use Grapple/frag; this change does not implement
Grapple/A-Wall automation or broaden normal bot loadouts. No weapon damage,
aim or ability cooldown values changed in this implementation.

Normal rollback backup: before-v18-normal-deploy-20261025-194834 under the
private audit Notes/backups folder. Restore deployment files only, explicitly
disable the new bridge when returning to v16, and keep current save_data.
The abandoned fresh candidate profile still has an unresolved startup issue;
successful tests used the backed-up original isolated profile. No temporary
schema/native prewarm code or base-game edits remain.

Read the latest handoff and live private survey status before touching a game
process. Historical PIDs/status records do not establish current queue state.
No visual match watching or recorder was used. Map-specific route hotspots,
Titan behavior and hide-and-seek support remain further work.
See research/maps-v18-20261026/FINDINGS.md for full results, evidence hashes,
public replay/reference checks, phase limits and final environment verification.
