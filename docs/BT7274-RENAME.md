# BT-7274 rename — 2026-10-27

The repository owner is referred to as **BT-7274** everywhere (prose), and the
former personal add-on prefix is now **`BT7274`** in identifiers. This is a
source change only; the installed profiles keep their old names until migrated.

## What changed

| Kind | Now |
|---|---|
| Prose and possessives | `BT-7274`, `BT-7274's` |
| Add-on folders / mod names | `BT7274.<Name>` (BotLifecycle, BotDecisions, LocalPersistence, TacticalRecharge, WeaponHandling, WeaponReload; test harnesses MapSurvey, BotCycleTest, DecisionTest, … in `automation/`) |
| Script globals | `BT7274<Name>_*` |
| Convars, weapon attachments, script files | `bt7274_*` (e.g. `bt7274_ads_trial`, `bt7274_solo_reload`, `bt7274_local_persistence.nut`) |
| Constants | `BT7274_*` |
| Machine paths | `%USERPROFILE%` in docs/JSON/`.cmd`; `$env:USERPROFILE` in PowerShell (same location on the owner's PC) |

Applied to every tracked text file **including** historical snapshots under
`history/`, `Notes/backups/` and `Notes/source-snapshots/`, and to the published
`.gz` logs (decompressed, renamed, recompressed). The third-party MIT text in
`bspeater` ("THE AUTHORS") is a license term and was not changed. Git history
still contains the previous wording; history was not rewritten (no force-push).

## Hashes

Hashes recorded in manifests, provenance and verification files describe the
content **at the time they were recorded** (before this rename; many already
differed for line-ending reasons, see `docs/DATA-PROVENANCE.md`). They were not
rewritten. The exact pre-rename bytes are in git at `1ae9d73` (main before the
rename) and the v20 candidate branch head.

## Installed profiles: migrate before deploying renamed packages

Northstar keys `save_data` by mod name, so renaming `LocalPersistence` would
otherwise start from empty loadouts. `tools/Migrate-BT7274Rename.ps1`:

```powershell
# 1) Dry run (default): shows every planned action, changes nothing
./tools/Migrate-BT7274Rename.ps1 -Profile "$env:USERPROFILE\northstar-crash-audit\map-cycle-test-profile"
# 2) Apply to the ISOLATED profile first, installing renamed packages from this checkout
./tools/Migrate-BT7274Rename.ps1 -Profile "$env:USERPROFILE\northstar-crash-audit\map-cycle-test-profile" -InstallFrom . -Apply
```

It discovers the old prefix from `enabledmods.json`, backs up `enabledmods.json`,
affected `.cfg` files and old `save_data` folders, **copies** save data
(byte-verified; originals untouched), enables `BT7274.*` with the old on/off
state while setting old keys to `false` (both enabled would define the same
script globals), and renames convar lines in profile `.cfg` files. It refuses to
run with the game open, refuses ambiguous prefixes, and will not overwrite a
different existing `BT7274.*` save without `-Force`. Reruns are idempotent.
Fixture test: `tests/migrate_rename.ps1` (15 checks).

After applying: start once, confirm the log shows the `BT7274.*` add-ons, 902
restored loadout fields, the human reload/tactical/ADS/role trials active, and
no script errors; then repeat for the normal profile. The native DLL contains no
renamed identifiers, so v19 and v20 DLLs work with either naming.

Launchers outside the repository (desktop shortcut, audit-root `.cmd`) keep
working: the in-repo PowerShell defaults resolve to the same folders through
`$env:USERPROFILE`.

Rollback: close the game, restore the backed-up `enabledmods.json` and `.cfg`
files from the migration backup folder. Old mod folders and old save data were
never modified.
