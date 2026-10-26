# Weapon review — 2026-10-24 (research only)

> **2026-10-26 correction:** The prior table's "Alternator (hemlok_smg)"
> row is actually the **Volt**. Northstar identifies the Alternator as
> `mp_weapon_alternator_smg`, with reference MP near/far body damage 35/18,
> fire rate 10 shots/sec (600 RPM), base magazine 20 and reload/empty reload
> 2.3/2.7 seconds. The original research table is left as historical evidence,
> not reinterpreted as a live Alternator measurement. The referenced 40-round
> extended magazine and the loadout entries labeled "Alternator" also refer
> to the Volt class in those records; actual private loadout names should be
> confirmed in-game before drawing conclusions about saved weapon choices.

James asked to look into weapon stats and possible improvements. No gameplay,
weapon, bot or save settings changed and no game restart was performed.

Northstar weapon KeyValues expose damage/falloff, headshot multipliers,
fire rate, recoil/viewkick, spread, reload/empty reload, magazine size,
projectile speed and handling timings. The menu stat_damage/stat_accuracy/
stat_range/stat_rof fields are separate display ratings, not actual damage.
Documentation: https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/

Research copies and GitHub blob hashes: research/weapon-stats-20261024.
Source: BigSpice/TitanFall-2-Skin-Modding, Weapon_Scripts, via GitHub contents
API. These are published reference definitions, not a new live runtime dump.
MP_BASE values must be used rather than SP overrides. Actual installed
runtime values/modifiers should be read in the isolated game before tuning.

| Reference weapon | Near body damage | Shots/sec | RPM (derived) | Base magazine | Reload / empty sec |
|---|---:|---:|---:|---:|---:|
| G2 | 40 | 5.5 | 330 | 14 | 2.2 / 2.64 |
| Alternator (hemlok_smg) | 25 | 11 | 660 | 33 | 1.5 / 2.0 |
| R-201 (rspn101) | 25 | 13.5 | 810 | 24 | 2.2 / 2.92 |
| CAR | 25 | 14.1 | 846 | 30 | 1.8 / 2.53 |

Reference named attachment mods: pas_fast_reload multiplies reload and empty
reload by 0.7 (30% shorter), extended_ammo sets G2 to18, Alternator40,
R-201 to30 and CAR36. James's saved slots0/1 already use both extended_ammo
and pas_fast_reload on G2/Alternator; slot2 R-201 uses extended_ammo and
pas_run_and_gun. Saved slot3 EVA-8 has empty mod1/mod2. None were edited.

Cautious proposal, not implemented: start with attachments already available
on a chosen gun. If still desired, trial around10% shorter reload time or
small handling improvements, one gun at a time. Avoid blanket damage/fire
rate increases given James's reported high K/D and preference for close/fair
matches. Damage changes can cross shots-to-kill thresholds. Global weapon
edits also affect bot-held copies; a human-only variant needs deliberate
named-mod application and client/server validation. Weapon tuning alone does
not fix navigation or weapon-specific bot tactics.

Shotguns and bolt-action/projectile weapons need extra interpretation:
EVA damage is not a simple rifle bullet number; spread/pellet distribution
matters. Kraber's fire_rate field alone is not effective cadence because it
also has rechamber_time. Do not compare them by raw fire_rate alone.
