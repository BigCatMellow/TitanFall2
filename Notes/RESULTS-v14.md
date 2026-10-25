# v14 navigation recovery — 2026-10-24

STATUS: REJECTED. None of these v14 candidates was deployed to the everyday
profile. The final progress-aware run (15:48:47, hash below) had 89
low-movement observations on Eden versus 1 in the disabled baseline, and
18 on Wargames versus 29. Mixed results and the Eden regression led to
restoring the v12 target/path code and trying the smaller v15 physical
backstep change. Archived v14 filenames containing "final" are not approved
builds. Read CURRENT-SETUP.md for the actual deployment.

Working baseline backup:
`backups\working-v12-before-recovery-20261024-151754`.
The backup contains 2671 files / 701406910 bytes, verified against its
SHA256 manifest. It includes the local source, three profile mods/plugins/
save_data/configs, core Northstar files, launcher and notebook files.
`Restore-Working-V12.cmd` restores the solo DLL/config/launcher and preserves
newer local loadout saves. It verifies the v12 DLL hash before copying.

## Implementation

The completed DLL is route-recovery-v14, SHA256:
`7A078607D4B7D251B415BAFB336A153E0C898C04EEBBD0C13F03DD0A17692E09`.
The rejected raw-persistence v13 is unrelated and is not included.

The new flag `bot_route_recovery` defaults to zero. With one, legacy pilot
mode 6 uses bounded failed-goal memory for unseen pursuit, grounded
breadcrumbs for short retreats, and diagonal backing-away after repeated
stalls. Visible enemies retain priority, and the only available enemy is
never excluded. Death/hull/map changes reset navigation state.

Source inspection also found an active-waypoint bug: popping the final node
empties the queue before reaching that node, causing repeated rebuilding.
With the new flag enabled, the bot keeps walking toward the active waypoint
until it is reached, a changed/moved goal requires another route, or the
progress watchdog invalidates it. Terminal reuse is capped at half a second
so the bot still refreshes for nearby changes. Reuse additionally requires
observed grounded progress toward the active waypoint. Stationary bots or
bots sliding sideways retain immediate empty-queue refresh. This is covered
by regression tests.

The full 27-test suite and the distribution build pass; git diff --check
passes. Existing native buffer and map-teardown fixes remain. No new native
function or ABI binding was introduced. A pre-existing unused-import warning
in shared bindings and standalone-test dead-code warning remain harmless.
Full source (including untracked modules) is archived at
`source-snapshots\v14-progress-20261024.zip` with a tracked-change patch beside it.
Archive SHA256:
`27BDD016B8823CE0A1A15B4C3293244C694E798A1C3510B36F36B979E73CACCD`.

## Comparison boundaries

The disabled baseline is `nslog2026-10-24 15-25-08.txt`, using the earlier
v14 candidate with recovery disabled (DLL SHA256 10C07F1A6B723689C8459BB4C14A726C7DC3D1124A5FF764F461D8D2C19E1B3A).
It recorded 30 bot joins across Eden and Wargames, 15 bots per map, and no
logged script errors/access violations/panics. Eden: 531 samples, one
low-movement sample, 3287 route requests. Wargames: 549 samples, 29
low-movement samples, 13253 route requests. Coordination 1, aim error 0.80.

Runs at 15:29:16 and 15:32:19 are exploratory candidates, not the final DLL.
The first lacked grounded-only breadcrumbs; the second lacked the final
waypoint fix. They must not be presented as final build evidence.

The run at 15:36:08 used an intermediate waypoint cache without the half-second
cap (DLL 58029456C01E6A8AAFB1EF6048FBB1B3176BF470846662E4FFDF319D646B952B).
Eden route requests dropped to 601, but it had 23 low-movement samples versus
one in the disabled run. This concern led to bounded refresh. Files named
v14-final-20261024 and route-recovery-v14-final.dll are intermediate artifacts;
do not confuse their names with the deployed/approved hash above.

The half-second-only candidate (C61F9BD054B10F9897C729C140F7A2EDDFF00B41603F039B09E2116F05A3B0AC)
is `nslog2026-10-24 15-41-47.txt`. It had 26 low-movement samples on Eden and
54 on Wargames, versus 1/29 in the disabled run. It was rejected for everyday
deployment; source snapshot v14-bounded-20261024 and its DLL are intermediate.

The progress-aware candidate starts at 15:48:xx; its exact log/results are
recorded below after completion. Tests keep 8v8,
coordination and aim settings equal, but random spawns/encounters and a
stationary human prevent a controlled performance or gameplay benchmark.
Two-second samples indicate movement/combat state, not terrain or video.
Low-movement samples are not counts of distinct stuck incidents. A native
route request reduction alone cannot establish smoother play or higher FPS.

Final deployment and observed results are recorded below after inspection.
