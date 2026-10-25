# Tactical recharge, 2026-10-24

James requested 30% less pilot tactical recharge, then changed the target to
50% while implementation was underway. Only the 50% version was installed.

## Installed scope

James.TacticalRecharge 1.0.0 is a separate script/KeyValues mod in the
everyday solo profile and isolated test profile. Source:
`C:\Users\james\bp-ort-fork\James.TacticalRecharge`.

The local human's Grapple, Cloak, Stim, Holo Pilot, Phase Shift, Pulse Blade
and A-Wall use half their normal recharge time. Native refill rates are
multiplied by 2; refill-start delays by 0.5. Ability duration, cost, range,
strength and charge count remain unchanged. Time while an ability is active
is not part of the recharge reduction. Power Cell remains multiplicative.
Bots, Titans and ordnance are excluded. This is for the solo insecure-auth
profile; local-player and insecure-auth checks exclude remote/public play.

Grapple uses a named ClassMod under `pilot_mp/global/ClassMods` in
`scripts/players/mp/pilot_mp.set`. The other six use named weapon Mods.
The server applies the named modifier one frame after loadout/respawn,
preserving existing modifier arrays and avoiding duplicate stacking.
No native DLL, local persistence mod or saved loadout fields were changed.

## Actual isolated game validation

Log: `map-cycle-test-profile\logs\nslog2026-10-24 21-25-30.txt`.
Harness/results archived in `Notes\tests\tactical-recharge-20261024`.
Tests used actual GivePilotLoadout calls with each of seven suits and
Power Cell equipped. All seven passed in the running game:

| Tactical | Original refill rate with Power Cell | Enabled rate |
|---|---:|---:|
| Phase Shift | 17.9995 | 35.9991 |
| Holo Pilot | 10.8 | 21.6 |
| Stim | 10.8 | 21.6 |
| Cloak | 13.5 | 27 |
| Pulse Blade | 10.8 | 21.6 |
| A-Wall | 6.75 | 13.5 |

Six tests also checked unchanged fire_duration, ammo_clip_size, ordnance
refill rate, halved refill-start delay, repeated activation without stacking,
and return to original rate when disabled. Grapple was timed by draining
native suit power to zero: full recharge 24.7 seconds disabled, 12.4 enabled
(test conditions, Power Cell equipped). Power Cell's class modifier remained
present; the recharge modifier removed correctly when disabled. All 15 bots
were checked and had neither the named player nor weapon recharge modifier.
No script compile/runtime errors were logged during this test.

The isolated cycle harness was restored from its pre-change backup and the
test-only James.TacticalProbe was moved outside active mods after validation.
The test loadouts never touched the real save. The real save SHA256 matched
its pre-change backup immediately before the normal-profile restart.

## Disable / rollback

Server console: `james_tactical_recharge 0`, then respawn or reselect the
loadout. Use 1 to enable, followed by respawn/reselection. For persistent
disable, add the 0 setting to the solo autoexec_ns_server.cfg. Alternatively,
close the game and move James.TacticalRecharge out of the solo mods folder.
Do not restore old save JSON just to remove this mod.

Backup before work:
`Notes\backups\before-tactical-recharge-20261024-210739` includes real saves,
solo autoexec, launcher and original isolated cycle harness. Source snapshot:
`Notes\source-snapshots\tactical-recharge-1.0.0-20261024.zip`.
Native v15 DLL remains SHA256
`2A68A1CE0C0AB6294DE62C7E2742BE064C7ED086111C8251F1822FCCD22FA66C`.

## References

Native local compiled pilot_mp.set and stock scripts were used for the
ClassMods syntax, SetPlayerSettingsWithMods and weapon SetMods behavior.
[Northstar KeyValues](https://docs.northstar.tf/Modding/guides/keyvalue/) and
[weapon fields](https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/)
document the mod folder structure and refill rate/delay fields.

Normal-profile restart: nslog2026-10-24 21-28-40.txt, 21:29:38 applied the
modifier to the real player's Pulse Blade; restored 902 named fields;
21:29:40 menu cache mismatch count 0. The canonical launcher used -fullscreen.
Source ZIP SHA256: F4C741EEA3D7A9625054A4BF52F9749D9F90E7FA4B588A8B6445853AAD5B682C.
Normal-profile verification at 21:30: 16 occupied player slots, teams 8/8,
15 bots, aim_error_scale 0.78, zero logged script/compile/error entries.
All 902 saved field values still match the pre-change real-save backup.
