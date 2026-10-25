# Observer and replay

Double-click Capture-Latest.cmd, or run:

```powershell
pwsh -NoProfile -File 'C:\Users\james\northstar-crash-audit\Notes\tools\Export-BotSession.ps1' -Open
```

For a specific session, add `-LogPath '<full nslog path>'`. Re-exporting a
growing log refreshes that session's files. Use the replay's Reload capture
button after exporting again. The exporter takes a snapshot; it does not
run continuously in the background.

## What the new logs show

- BOT_FRAME: map, map epoch, simulation time, and coordination on/off.
- BOT_PLAYER: all connected players, including the human, team, native alive
  state, Titan state, health, and position.
- BOT_TRACE: bot target, visibility, behavior state, position of the target,
  speed, route nodes, and cumulative switch/recovery/path/jump/spacing counts.
- BOT_DECISION and BOT_RECOVERY: changes and recovery events with simulation
  time and slot. Cumulative counts reset with bot/map state.

`bot_telemetry_interval 2` enables snapshots every two simulated seconds;
zero disables the structured observer. `bot_motion_debug 1` retains the older
ten-second movement log. `bot_team_coordination 0` restores the original
pilot target selector and turns off the new spacing behavior while keeping
the observer available for comparison.

## Export contents

Each `sessions\<log-name>` folder contains:

- replay.html: self-contained interactive position replay; select a round,
  scrub time, play at 10×, select a bot, or show target lines.
- observations.csv: per-player/bot samples.
- bots.csv: per-bot counts and stall/crowding observations.
- summary.json and metadata.json: map-level summary and provenance.
- events.json: decision/recovery event records.
- archived.log: log snapshot with common authentication query-token values
  redacted. The original log remains in the game profile.

White markers are human players, blue/red are teams, squares are Titans,
and yellow rings flag low movement over ten seconds. Lines show selected
targets; they do not claim that a route through the walls is possible.

The assistant can read the same CSV/JSON/log data to identify repeated stuck
locations and target switching. The computer-use tools in this session did
not expose a desktop/browser surface, so visual playback still needs a local
browser opened by you. Replay JavaScript is syntax/runtime checked separately.
