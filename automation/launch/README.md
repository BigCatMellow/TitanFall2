# Installed solo launcher source

Copy Play-Solo-Bots.cmd to C:\Users\james\northstar-crash-audit.
Its relative paths assume that installed location, beside local-test-profile and
TitanFall2-project. The existing Desktop shortcut targets that installed copy.
The launcher starts tools/Start-SoloWeaponSession.ps1, which preserves the 8v8
Eden/fullscreen/loopback flags and adds the local text-note collector.
Run the installed CMD with --check to check paths without launching the game.
See Notes/weapon-notebook/README.md for recording output and measurement limits.
