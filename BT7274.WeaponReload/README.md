# BT7274.WeaponReload

Source version 1.0.1: 10% shorter reload times on G2, Alternator, Volt, R-201
and CAR for the local human in BT-7274's insecure solo profile. Normal, empty and staged remaining
reload times are multiplied by 0.9. Existing Speedloader multiplies normally
(0.7 x 0.9 = 0.63 of base time).

**Runtime status:** 1.0.1 was tested and installed October26: all five guns,
Speedloader off/on, eight timing fields, duplicate/reversal, automatic application
and bot stripping checks passed. See the [rollout record](../Notes/candidates/weapons-v19-20261026/README.md).
The historical 1.0.0 test that was
labeled Alternator actually exercised `mp_weapon_hemlok_smg` (Volt). The
Alternator's real name is `mp_weapon_alternator_smg`. The candidate preserves
the existing Volt modifier and adds the intended Alternator modifier. Do not
interpret the archived 1.0.0 results as a passed Alternator runtime test.

Damage, fire rate, magazine, recoil, spread, handling and other weapons are
unchanged. A named weapon modifier is applied after respawn, loadout change
or inventory change. Existing mods are preserved; duplicate applications
do not stack. The modifier is removed when a bot/other player receives the
weapon through an inventory callback. It is not serialized into loadouts.

To disable, set server convar `bt7274_weapon_reload 0`, then respawn or
reselect the loadout. Add that setting to the solo autoexec for persistence.
Alternatively close Northstar and move this directory out of profile/mods.
Install only in the solo profile; restart Northstar to load the add-on.
