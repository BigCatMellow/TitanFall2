# Local Pilot and Titan loadouts

The solo launcher connects directly to a local map with insecure local
authentication. Northstar's normal cloud persistence is not used on that
path. In the installed core source, the insecure persistence-write branch
is a TODO; enabling ns_auth_allow_insecure_write alone does not add saving.
Official context: https://docs.northstar.tf/Wiki/hosting-a-server-with-northstar/local-only-server/

## Named-field save add-on

Source: `C:\Users\james\bp-ort-fork\James.LocalPersistence`.
The Squirrel-only add-on uses Northstar Safe IO and the normal
GetPersistentVar / SetPersistentVar APIs. It does not replace the stable
team-observer-v12 bot DLL, change bot skill, or reset persistence.

It saves Pilot and Titan loadout slots, equipped slot selections, faction,
boost, calling card and icon. It saves changed data after loadout commands
and checks for changes every second. Only the local human with insecure
local authentication is eligible; bots and remote players are ignored.

Files live in:
`C:\Users\james\northstar-crash-audit\local-test-profile\save_data\James.LocalPersistence`.
`loadouts_<UID>.json` is current and `previous_<UID>.json` is the preceding
snapshot. Files use format version 1 and 440 named fields. Empty enum values
are normalized to empty strings, as stock loadout helpers do, because
Northstar's JSON encoder otherwise omits null entries.

Existing unreadable, incompatible or failed-to-restore files pause autosaving
and are preserved. Logs contain LOCAL_LOADOUTS messages. The setting
`james_local_loadouts 0` disables the add-on. Removing the mod disables it
without erasing its save files. This is profile-local loadout saving, not
cloud sync, match-preset saving, or XP/stat saving.

Changes need roughly one second of normal game operation to reach the
asynchronous save API. A crash during a write remains a limitation; the
previous snapshot is kept separately. Presets lost before this add-on was
installed cannot be promised recoverable; set desired loadouts once and
subsequent solo launches should restore them.

## Tests and recovery boundaries

Tests use only `map-cycle-test-profile` and its James.BotCycleTest harness.
The harness sets a synthetic first-slot name JAMES_LOCAL_SAVE_PROBE and G2
primary, then checks both after reconnect/restart. Never copy its JSON or
test harness to the everyday profile.

Verified 2026-10-24:

- `nslog2026-10-24 14-57-05.txt`: initial named save, test name/G2 captured,
  and restored after Relic changed to Wargames. This first format omitted
  null enum slots (333 fields); the final version normalizes those values.
- `nslog2026-10-24 15-02-06.txt`: full process relaunch retained name/G2,
  upgraded the snapshot to 440 fields, then restored all 440 on Wargames
  at 15:04:35. No script errors or restore failures were found.
- `nslog2026-10-24 15-04-59.txt`: another complete process restart restored
  all 440 at 15:05:48 and passed the name/G2 assertion at 15:05:49.
- Final source `git diff --check` passed. No new native DLL was built or
  deployed for this script fix. Source archive:
  `source-snapshots\local-loadouts-1.1.0-20261024.zip`.
- Script SHA256:
  `35EB9CA355ADB6CE4600DC792EC269D5F005BB35F8A1B9AD2C294DA0A0F2C150`.

The everyday profile received only the add-on source, never synthetic test
JSON. The regular Program Files profile did not receive this local add-on.
The everyday Eden game was reopened at 15:06:09; at 15:06:57 it wrote its
first 440-field snapshot. Its first slot was confirmed free of the synthetic
test marker. The stable v12 DLL hash was rechecked after deployment.

The initial raw-buffer native v13 restore experiment was rejected after a
client-side empty weapon-name error in the isolated profile. It was never
installed in the everyday solo profile. Its DLL hash is
47AC5A1ED0B2D480D2D64D0327BD16F44428D0E8BA4304351E6CB9ACFC16FE23.
Raw buffers, rejected source/codec and the capture tool are archived under
`backups\presets-before-v13`. These are diagnostic artifacts, not supported
loadout recovery files. The capture tool was removed from active tools and
the rejected native persistence modules were removed from the live source.
Do not restore these raw buffers or re-enable that DLL.

Stable bot DLL SHA256 remains:
1183389B692F59758C569631F0C7BAB50703C7FB425212876DBB5ABB8DBE7D7A.
