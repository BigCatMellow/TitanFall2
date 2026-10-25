# James.WeaponReload

10% shorter reload times on G2, Alternator, R-201 and CAR for the local
human in James's insecure solo profile. Normal, empty and staged remaining
reload times are multiplied by 0.9. Existing Speedloader multiplies normally
(0.7 x 0.9 = 0.63 of base time).

Damage, fire rate, magazine, recoil, spread, handling and other weapons are
unchanged. A named weapon modifier is applied after respawn, loadout change
or inventory change. Existing mods are preserved; duplicate applications
do not stack. The modifier is removed when a bot/other player receives the
weapon through an inventory callback. It is not serialized into loadouts.

To disable, set server convar `james_weapon_reload 0`, then respawn or
reselect the loadout. Add that setting to the solo autoexec for persistence.
Alternatively close Northstar and move this directory out of profile/mods.
Install only in the solo profile; restart Northstar to load the add-on.
