# Pilot preview race repair — 1.2.1

User error after a round, 2026-10-24 20:38:20:
sh_menu_models.gnut:2523 tried to animate an entity with no model.
Stack: UI Suit_Equip -> CLIENT SavePilotCharacterPreview ->
UpdatePilotModelDisplay -> PlayMenuAnim. The bodyModel local was empty.

The add-on's background refresh called stock UpdateCachedLoadouts_Delayed.
That helper waits one second, clears both pilot/Titan previews, then rebuilds
models. It ran at 20:38:19, immediately before the user equipped a tactical
ability. SavePilotCharacterPreview copied the cleared preview body into the
current body model, leading to the invalid animation call.

Version 1.2.1 removes that helper from both CLIENT and UI background refresh.
It updates only cached loadout data and selected-slot indices, leaving 3D
preview ownership to the menu. The 902-field save format, private-lobby
saving, initialization guard, XP retention, bot DLL, 8v8 and aim 0.78 are
unchanged. No core Northstar menu file or raw persistence buffer was patched.

## Reproduction and verification

An isolated regression probe went from an active match to the lobby, called
the real PreviewPilotCharacter function, sent a real loadout-name edit to
trigger synchronization, waited for the refresh, checked the preview, and
then called the real SavePilotCharacterPreview function.

- Control 1.2.0: nslog2026-10-24 20-43-36.txt, at 20:45:22 reported
  FAIL background sync cleared active character preview. The test avoided
  calling Save on that empty preview, preventing the expected fatal path.
- Repair 1.2.1: nslog2026-10-24 20-46-26.txt, passed equip cycles for geist
  at 20:47:59, medium at 20:48:03, and grapple at 20:48:07. At 20:48:08
  reported PASS all preview/equip cycles after match-to-lobby. No script or
  compilation errors were found. medium matches the original error's itemRef.

The test probe is archived under the backup directory and removed from the
isolated active mods afterward. It was never installed in the real profile.
These tests exercise actual preview/model calls, not a mock implementation;
they do not guarantee that every unrelated menu issue is eliminated.

## Backup and deployment

Backup: backups\preview-error-before-repair-20261024-203952, containing the
original add-on, latest real saves and validated preview test. Version 1.2.0
is retained for diagnosis; do not restore its background model-refresh calls.

At 20:49:32, installed only the updated add-on in everyday solo and reopened
the private lobby so the user can edit their loadout. Bots join when the
match starts. Existing real save JSON was retained. Desktop launcher remains
the same and loads 1.2.1 automatically on future starts.

Source archive: source-snapshots\local-loadouts-1.2.1-20261024.zip, SHA256
3C4ED170E919BB8F954EC8568AA70167DA21C9FF1482B5781D55F0B580C74A35.
Source git diff --check passed. Native code was unchanged; its independent
test suite was not repeated for this script-only repair.

Real-profile verification: nslog2026-10-24 20-49-32.txt restored all 902
fields at 20:50:22; cache-only refresh and UI mismatch count zero were logged
at 20:50:24/25. At 20:52:06, comparison with the pre-repair real save found
zero changed fields and zero new script/compile/native error lines. The
game was left in the private lobby, ready for loadout editing and match start.
