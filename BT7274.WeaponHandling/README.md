# BT7274.WeaponHandling — opt-in ADS trial

Runtime-field-verified trial for the local insecure solo Northstar profile.
**Source defaults OFF; enabled in the normal solo profile on October26.**
Flatline/G2 effective ADS fields, reload/Speedloader and role-mod coexistence,
automatic inventory application, forced-modifier stripping from bots, respawn
and lobby return passed. Visual timing/feel and actual physical weapon pickup
were not measured. [Rollout record](../Notes/candidates/weapons-v19-20261026/README.md).

The named attachment `bt7274_solo_ads_trial` multiplies **both** ADS transition
durations by 0.75 (25% shorter) for only:

| Weapon | Internal class | Reference ADS-in | Trial ADS-in | Reference ADS-out | Trial ADS-out |
| --- | --- | ---: | ---: | ---: | ---: |
| Flatline | `mp_weapon_vinson` | 0.250 s | 0.1875 s | 0.200 s | 0.150 s |
| G2 | `mp_weapon_g2` | 0.250 s | 0.1875 s | 0.200 s | 0.150 s |

Reference times are from publicly available Titanfall 2 MP weapon scripts,
not measurements of BT-7274's current installation. Verify those baselines in
the isolated game profile before interpreting actual timings. Existing weapon
attachments may further modify effective timings. This saves 62.5 ms entering
ADS (about 3.75 frames at 60 FPS) and 50 ms leaving ADS (3 frames): a stronger
handling experiment than the original 10% trial. It also brings these rifles
to about SMG-level ADS speed, which could weaken weapon-class differentiation.
Treat this as an upper-end test, not an automatically recommended final balance.

Damage, fire rate, recoil, hipfire/ADS spread, aim assist, bot aim, ADS movement
speed, deploy time, other weapons and Titans are unchanged. The existing reload
modifier is separate and must continue to work, including Speedloader.

The script follows the local-player guard and inventory callbacks used by
`BT7274.WeaponReload`: solo local living human pilot only; mods already on the
weapon are preserved, duplicate applications are skipped, and the trial mod
is removed on eligible inventory callbacks when disabled or transferred to
another owner. The explicit bot stripping path passed; physical pickup-event
coverage remains a separate follow-up.

## Isolated test procedure (reference and deeper follow-up)

1. Check the private v18 overnight survey is finished and its test profile
   restored; do not modify a profile during a frozen map queue. Back up the
   isolated profile's mod manifest, config and current saves; never restore
   old survey saves over later play.
2. Copy this folder to the isolated profile's `R2Northstar/mods` and enable
   `BT7274.WeaponHandling` with `bt7274_ads_trial 0`. Use its matching Northstar
   core. Boot and confirm no weapon KeyValue merge/parser errors, especially
   because `BT7274.WeaponReload` also contributes `mp_weapon_g2.txt`.
3. Equip Flatline and G2 without attachments. Record ADS-in/out with trial
   off, then set `bt7274_ads_trial 1` and respawn/reselect loadout; record again.
   Expect approx. 0.1875 s in / 0.150 s out before other modifiers. Compare
   with an SMG's ADS response so the rifles do not become overly responsive.
4. Verify that their other stats do not change; check a CAR or R-201 as an
   unchanged control. Verify both enabled trial and disabled trial with
   `BT7274.WeaponReload` and Speedloader still working on the G2.
5. Check a bot wielding Flatline/G2, death/respawn, changing weapons, dropping
   and picking up an adjusted weapon, toggling back off plus respawn, map/lobby
   transition, 8v8 population, errors, and unchanged personal save hashes.
6. If any KeyValue collision or unintended effect appears, stop: disable or
   remove **this** add-on; leave the normal profile and saves alone. Do not
   merge or deploy until the isolated test passes and results are reviewed.

Server convar: `bt7274_ads_trial 1` opts in; `bt7274_ads_trial 0` opts out.
After either change, respawn or reselect a pilot loadout to reapply the mod.
To unload the add-on entirely, close Northstar before removing its folder.

Sources: [Northstar weapon KeyValues](https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/),
[KeyValue modding guide](https://docs.northstar.tf/Modding/guides/keyvalue/),
[weapon script references](https://github.com/BigSpice/TitanFall-2-Skin-Modding/tree/main/Weapon_Scripts).
