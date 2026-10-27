# Loadout repair 1.2.0 — 2026-10-24

Superseded by 1.2.1 for background cache refresh: the 1.2.0 delayed helper
also rebuilt preview models and caused an equip-time race. The save/lobby
fixes below remain. Read PREVIEW-REPAIR-1.2.1.md before restoring this version.

The user reported loadouts and levels resetting again. Their real match log
and JSON showed loadout edits were saved during gameplay. However, the
private lobby ran BT7274LocalPersistence_Init without running the normal
connecting/connected callbacks used to start the save loop. The add-on was
therefore not initialized for lobby edits. A test that checked only server
fields during matches did not cover this flow or the separate UI cache.

## Changes

- Server initialization now also responds to a local-client ready command
  and watches for the local player, covering private lobby entry. Duplicate
  starts are prevented per player. Restore waits for stock persistent-data
  initialization, preserving the file if initialization times out.
- A CLIENT watcher refreshes stock CLIENT and UI caches when networked
  loadout fields change. UI diagnostics inspect actual cached Pilot slots
  and selected primary/mods/name. No direct manipulation of the raw native
  persistence buffer is used.
- Format 2 saves 902 named fields. Version-1 files migrate using their
  existing equipment. Added Pilot XP/generation, credits, weapon XP/mod
  flags, Titan/faction XP, and Aegis XP/points. Earlier levels absent from
  version-1 saves cannot be claimed recovered. This is basic progression,
  not all challenge/statistic/purchase history or cloud synchronization.

Source: `%USERPROFILE%\bp-ort-fork\BT7274.LocalPersistence`.
Real saves: `local-test-profile\save_data\BT7274.LocalPersistence`.
Current and previous JSON snapshots remain separate. The convar
bt7274_local_loadouts controls the whole add-on. Read failures pause writing.
The v15 bot DLL, 8v8 population and aim 0.80 are unchanged.

## Verified integration paths

- `nslog2026-10-24 18-32-22.txt`: version-1 migration to 902 fields; synthetic
  CAR, extended ammo, fast reload, name, XP 137, generation 2 and weapon XP 71
  saved. Actual UI cache showed the test name and equipment, mismatches=0.
- `nslog2026-10-24 18-34-36.txt`: full process restart restored all 902 fields
  and passed the name/weapon/attachments/XP assertions. Eden to Wargames,
  then lobby to Rise preserved data and actual menu caches. This first lobby
  pass exposed the missing server save initialization there.
- `nslog2026-10-24 18-40-43.txt`: cold private-lobby start restored 902 fields
  at 18:41:24. At 18:41:27 the CLIENT test sent the ordinary
  SetPersistentLoadoutValue command to rename slot 0 BT7274_LOBBY_EDIT_PROBE.
  The lobby server saved it immediately; UI reflected it at 18:41:30. Rise
  restored it at 18:41:46, passed the XP/equipment assertions, and displayed
  the same name/equipment in UI cache at 18:41:47. No script/compile errors
  were found in these tested paths.

Synthetic JSON was never copied to the everyday profile. The complete
special test harness is archived in the pre-repair backup; the isolated
native regression harness was restored afterward.

## Backup and deployment

Backup: `backups\persistence-before-repair-20261024-164632`, including the
original 1.1.0 add-on, original real saves, latest pre-restart real saves,
and the special validated lobby test harness. Raw .bin artifacts remain
diagnostic only and are not used for restoration.

At 18:42:30, only the add-on source was updated in the everyday profile and
normal 8v8 Rise was reopened. Existing real JSON was retained for migration;
the bot DLL was not replaced. Real-profile verification is recorded below.

Real-profile log `nslog2026-10-24 18-42-30.txt`: at 18:43:15 the real old
440-field save was restored and migrated to format 2 / 902 fields. At
18:43:16 the actual menu cache reported mismatches=0 and the saved LMG/
extended-ammo setup. Comparison against the latest pre-restart real backup
found zero changed original fields. No synthetic probe name or test harness
was present; 15 bots joined, and no logged script/compile/native errors were
found by 18:44:32. Native DLL remains the v15 hash in CURRENT-SETUP.md.

Source archive: `source-snapshots\local-loadouts-1.2.0-20261024.zip`, SHA256
`04E52DF29DB48A5FAD0D7C0B3948627714B5DF7FDA027A878801331EB2B74F95`.
Source git diff --check passed. The unrelated native tests were not rerun;
this was a Squirrel-only repair tested through the actual game and menus.
