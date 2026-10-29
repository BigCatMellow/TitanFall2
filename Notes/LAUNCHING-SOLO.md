# Launch the custom solo setup

Double-click the desktop shortcut **Northstar - Solo Bots (8v8)**.
It runs `%USERPROFILE%\northstar-crash-audit\Play-Solo-Bots.cmd` through
Windows cmd.exe, with a literal absolute script argument. This avoids
user-known-folder shortcut resolution changing the target in a sandbox.
The assistant is not needed to launch or keep the game running.

The script explicitly selects the existing local-test-profile, loads its
current mods/config/saves, binds localhost, and starts team deathmatch on a
random installed full-size map with a 16-player cap: one human plus 15 bots.
The 14-map pool excludes Eden, Live Fire and Coliseum; successive launches avoid
repeating the previous random selection. This chooses the starting map on each
launch, not an automatic between-round rotation. Explicit `-Map mp_eden` (or
another installed internal map ID) still works in Start-SoloWeaponSession.ps1.
Both solo and Full desktop shortcuts use the same launcher. Bots are added after the
match intro reaches Playing. The profile contains the v15 recovery trial,
coordination/observer, loadout saving 1.2.0, and the current 0.78 aim setting.
Future changes to this profile are picked up by the same shortcut.

Fullscreen default (2026-10-24): the script passes -fullscreen, and the
actual user video config at OneDrive\Documents\Respawn\Titanfall2\local\
videoconfig.txt was set to setting.fullscreen 1, retaining 1920x1080 and
setting.nowindowborder 0. The launcher flag enforces fullscreen even if the
running game's older windowed state writes back on exit. The file was not
made read-only. No current game restart was performed for this default change.

Use the private-match menus to choose another map/mode. Hide and Seek has
an open bot-compatibility issue. The regular Northstar executable/shortcut
loads R2Northstar by default and does not select this custom solo setup.
Close an existing Titanfall 2/Northstar instance before running the script;
the launcher checks for both process names and prevents duplicate starts.
It checks the executable and required profile/mod files before launching.
Steam/EA prerequisites are the same as for the existing working game.

For a file/path preflight without launching:
`Play-Solo-Bots.cmd --check`.

Northstar parses the raw command line for -profile=. Quote only its value:
`-profile="%USERPROFILE%\northstar-crash-audit\local-test-profile"`.
Quoting the whole argument as "-profile=..." leaves a trailing quote in
Northstar's parsed directory and triggers the misleading writable-log warning.
This was reproduced and corrected during launcher testing; no permission
changes or save resets were needed. A temporary log-file write check passed.

The original launcher is backed up at
`backups\launcher-before-20261024-202008\Play-Solo-Bots.cmd`.
The desktop shortcut points to the script, so corrections apply immediately.

Verified launch: nslog2026-10-24 20-22-27.txt reports the correct solo profile,
v15, 902 restored fields and zero menu-cache mismatches. By 20:24:10 all
15 bots were sampled and BOT_MOTION confirmed aim_error_scale=0.78, with
zero logged script/compile/native errors. The game was left running.
