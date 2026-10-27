# Recorder validation — 2026-10-26

Installed `Solo.WeaponNotes1.0.0` in normal and working isolated profiles. The
existing solo shortcut/CMD starts the hidden Node collector automatically.
No native, weapon, tactical, persistence or bot-setting change was made.
The damage injector exists only in the isolated profile and is disabled.

- 10 analysis regression checks: shared damage, incomplete sequences, healing,
  injured starts, modifier/config/weapon changes, life/map boundaries, overlap,
  forced/friendly/Titan damage, zero-length spans and unrelated-log filtering.
- 3 ideal-model checks: first hit at time zero, damage breakpoints, missing
  fields/reload limits and unsupported firing mechanisms.
- 1 live-tail fixture: split records, unrelated/private lines, owned-process exit
  and final summary generation.
- [Isolated runtime projection](isolated-validation.json): four synthetic cases
  plus actual bot combat. Validated before/after HP100→75→50→25→0 and elapsed
  injection timing. Shared attackers, injured starts and healing were detected.
  Injected damage lacks an engine-associated firing weapon, so its unknown mod
  stack correctly excludes it. Real combat produced known-modifier qualifying
  episodes; the projection preserves the reviewed snapshot, not a balance study.
- [Normal shortcut projection](normal-validation.json): actual Windows PowerShell
  launch, metadata/collector output, Northstar1.31.14, restored902fields and
  human+15bots. No script/native error markers. All44existing gameplay files
  checked remained hash-identical. This covers Eden startup/combat, not all maps.

Current saves were never restored. Two named-state JSON files changed in normal
game sessions for XP, weapon/Titan progress, kill counters and selected slots;
zero preset-definition fields changed. Preserve those current files.

## Corrections found during validation

The initial `AddPostDamageCallback` read still contained pre-deduction health.
The recorder now reads nonlethal health at the end of the frame and completes
lethal records from the killed callback. Overlapping pending hits are marked
incomplete; it never assigns a frame's total health loss to an arbitrary hit.
Synthetic timings use actual injection timestamps, because `wait0.1` can resume
late under load. The observed0.4s four-hit injection is not R-201 weapon TTK.

Initial Squirrel type/syntax errors were corrected in isolation. An empty
leftover survey loadout blocked the test intro; the disposable profile was
seeded from CURRENT normal named-loadout copies. No test data went into normal.
Windows PowerShell lacked the expected hash helper and expanded `Get-Content`
string metadata during JSON serialization. The launcher now uses .NET hashing
and plain regex-captured settings. The actual shortcut was retested successfully.
Failed startup attempts remain private and are not counted as successful tests.

## Backup and rollback

Private backup: `Notes/backups/before-weapon-notes-20261026-193842` under the
audit root, including both profiles' then-current saves/config/enabledmods and
the previous launcher. It is protection/history, not a source for replacing
newer progress. Roll back the launcher and explicitly disable
`Solo.WeaponNotes` version1.0.0 in enabledmods, preserving CURRENT save_data.
Keep the independent weapon-v19 installation. Recording sessions stay local
under audit `Notes/weapon-notebook/sessions`; nothing auto-uploads them.
