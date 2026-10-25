# James.TacticalRecharge

Pilot tactical recharge takes half its usual time for the local human in
James's insecure solo Northstar profile. Seven supported tacticals: Grapple,
Cloak, Stim, Holo Pilot, Phase Shift, Pulse Blade and A-Wall.

The mod doubles native refill rates and halves native refill-start delays.
Ability duration, strength, range, charge count and energy cost are unchanged.
Power Cell composes with the multiplier. Bots, Titan abilities and ordnance
are excluded. Public/remote servers are excluded by local-player and insecure
authentication checks.

Grapple uses a named player ClassMod in scripts/players/mp/pilot_mp.set.
The other six use a named weapon Mod. Existing modifier arrays are preserved;
repeated respawns/loadout changes do not stack copies. Activation runs one
frame after respawn/loadout application.

Install this directory in the solo profile's mods folder, then restart
Northstar. To disable: set `james_tactical_recharge 0` in the server console,
then respawn or reselect the loadout. For persistent disable, add that setting
to the profile's autoexec_ns_server.cfg. Removing this directory with the game
closed also restores stock recharge. No loadout save edits are required.

Scope is the recharge period: unchanged active ability duration is not cut
in half. This add-on does not alter the base single-player campaign.
