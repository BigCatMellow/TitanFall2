# Northstar bot project — start here

This folder is the project notebook and recovery kit for BT-7274's solo
Titanfall 2 / Northstar bots. Everything here stays on this computer.

To play, double-click **Northstar - Solo Bots (8v8)** on the desktop.
See [launch instructions](LAUNCHING-SOLO.md).

- [Current setup and build status](CURRENT-SETUP.md)
- [Handoff guide for a future assistant](HANDOFF.md)
- [What changed and why](HISTORY.md)
- [Known issues and troubleshooting](KNOWN-ISSUES.md)
- [Observer and replay instructions](OBSERVER.md)
- [Your earlier rounds, including Glitch](sessions/nslog2026-10-24_13-21-12/replay.html)
- [Coordination test replay](sessions/nslog2026-10-24_13-58-30/replay.html)
- [New Glitch match with detailed tracking](sessions/nslog2026-10-24_14-13-53/replay.html)
- [Measured v12 comparison](RESULTS-v12.md)
- [Local loadout saving and recovery boundaries](LOCAL-LOADOUTS.md)
- [Loadout/lobby/menu repair 1.2.0](PERSISTENCE-REPAIR-1.2.md)
- [Post-round preview repair 1.2.1](PREVIEW-REPAIR-1.2.1.md)
- [Bot findings from longer Glitch and Eden rounds](BOT-FINDINGS-20261024.md)
- [v15 escape trial and results](RESULTS-v15.md)
- [Rejected v14 experiments](RESULTS-v14.md)
- [Recent bot/player review and tiny accuracy trial](REVIEW-20261024-1958.md)

The verified working v12 backup is
`backups\working-v12-before-recovery-20261024-151754` (source, three profiles,
core files, settings and loadout saves; SHA256 manifest included).
`Restore-Working-V12.cmd` restores the solo bot DLL/config/launcher while
preserving current local loadout saves. Close Northstar before using it.

Double-click **Capture-Latest.cmd** to export the current solo log and open
its replay. Reports are saved in `sessions`, previous working files in
`backups`, and source archives in `source-snapshots`.

To resume later, tell the assistant:

> Read %USERPROFILE%\northstar-crash-audit\Notes\HANDOFF.md and
> CURRENT-SETUP.md, then continue the Northstar bot project.

The live source checkout is `%USERPROFILE%\bp-ort-fork`.
