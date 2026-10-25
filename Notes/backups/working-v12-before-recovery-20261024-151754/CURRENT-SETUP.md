# Current setup

Updated 2026-10-24. Deployment status must be checked here before further edits.

## Status

- Everyday solo profile: **team-observer-v12**, installed and checked in a
  visible 8v8 Glitch match. Fifteen bots joined and detailed movement/combat
  observations were recorded with no logged errors; responsive after several minutes.
- Regular and isolated profiles also contain **team-observer-v12**, SHA256
  `1183389B692F59758C569631F0C7BAB50703C7FB425212876DBB5ABB8DBE7D7A`.
- v11 SHA256:
  `DBE7301BFCAEF61E16165B3456D9F8EF851807DF2F64EDD768E2A9928EC63C48`.
- Northstar core: 1.31.14. OctBots is not active.
- Solo Pilot/Titan loadouts now use the script-only James.LocalPersistence
  1.1.0 add-on. The v12 DLL and 8v8/0.80 settings are unchanged.
  See [local saving](LOCAL-LOADOUTS.md) for files, tests and recovery limits.

## Paths

| Item | Location |
|---|---|
| Game | `C:\Program Files (x86)\Steam\steamapps\common\Titanfall2` |
| Regular profile | Game directory + `\R2Northstar` |
| Everyday solo profile | `C:\Users\james\northstar-crash-audit\local-test-profile` |
| Isolated test profile | `C:\Users\james\northstar-crash-audit\map-cycle-test-profile` |
| Solo launcher | `C:\Users\james\northstar-crash-audit\Play-Solo-Bots.cmd` |
| Source checkout | `C:\Users\james\bp-ort-fork` |
| Session logs | Each profile's `logs` directory |
| Before-v12 backup | This folder's `backups\v12-before` |

## User preferences and settings

James wants lively solo battles, working Titan controls, moderate difficulty,
and enough bots to fill the map. 8v8 was enjoyable and is the selected size.

```
bot_manager_max 16
bot_manager_target 16
bot_manager_enabled 1
bot_cmds_type 6
bot_aim_penalty_speed -1
bot_aim_error_scale 0.8
bot_motion_debug 1
bot_team_coordination 1
bot_telemetry_interval 2
```

Sixteen is the total player count: James plus 15 bots. The launcher explicitly
uses `-maxplayersplaylist` and `+setplaylistvaroverrides "max_players 16"`.
Keep localhost binding `-ip 127.0.0.1 -port 37025`, public listing off, and the
existing solo authentication settings. Normal solo matches return to lobby.

The `James.BotLifecycle` server mod enables bot joins after the match intro.
The automated `James.BotCycleTest` harness belongs only in the isolated profile.

The v12 options are `bot_team_coordination 1` and `bot_telemetry_interval 2`.
Their plugin defaults are zero. Coordination affects legacy pilot mode 6;
Titan controls retain the existing selection/control path.

Coordination and snapshots are enabled in the everyday solo config. The
regular profile contains the new DLL but its options retain their defaults
unless explicitly configured. The isolated test config is currently set to
coordination zero for the comparison. See [v12 results](RESULTS-v12.md).

[Latest verified Glitch replay](sessions/nslog2026-10-24_14-13-53/replay.html).
Source snapshot: `source-snapshots\v12-source-20261024-141554.zip` with its
manifest and tracked-change patch beside it. The source archive includes
untracked new modules/tests as well as the workspace sources.
