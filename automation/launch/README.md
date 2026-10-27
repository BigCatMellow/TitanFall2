# Installed solo launcher source

Copy Play-Solo-Bots.cmd to %USERPROFILE%\northstar-crash-audit.
Its relative paths assume that installed location, beside local-test-profile and
TitanFall2-project. The existing Desktop shortcut targets that installed copy.
The launcher starts tools/Start-SoloWeaponSession.ps1, which preserves the 8v8
Eden/fullscreen/loopback flags and adds the local text-note collector.
Default preset: Movement. Optional CMD arguments: baseline, height, roster,
skills, full. These select only validated candidate settings, record the preset
and back up server config before changing it. The native validation receipt is
checked before launch; other play settings and saved loadouts are preserved.
Run the installed CMD with --check to check paths without launching the game.
See Notes/weapon-notebook/README.md for recording output and measurement limits.
