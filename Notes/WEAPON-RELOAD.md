# Pilot weapon reload adjustment — 2026-10-24

> **2026-10-26 correction to historical evidence:** `mp_weapon_hemlok_smg`
> is the **Volt**, not the Alternator. The archived 1.0.0 measurements labeled
> "Alternator" were Volt measurements. The actual Alternator
> (`mp_weapon_alternator_smg`) was not modified or runtime-tested in 1.0.0.
> Source candidate 1.0.1 preserves the four previously affected weapons and
> adds the Alternator, but requires a fresh isolated engine validation before
> deployment. The original contemporaneous record below is preserved.

Scope: James approved the modest weapon changes proposed in the read-only
review. Implemented as James.WeaponReload 1.0.0: 10% shorter reloads on G2,
Alternator, R-201 and CAR for the local insecure-solo human. Existing
Speedloader stacks multiplicatively: 0.7 x 0.9 = 0.63 of stock reload time.
Normal, empty and remaining reload checkpoint timings are scaled by0.9.
Damage, fire rate, recoil, spread, handling, magazine and other guns unchanged.

Source: C:\Users\james\bp-ort-fork\James.WeaponReload
The named james_solo_reload weapon mod is added after respawn/loadout or
inventory change; existing attachment arrays are preserved. Repeated
application cannot stack. For bots/other owners the modifier is removed on
inventory change, covering a transferred human weapon. The addon has no
persistent loadout writes. It does not edit native bot code or cooldown code.

Disable: server convar james_weapon_reload 0 then respawn/reselect loadout.
For permanent disable add that setting to solo autoexec, or close Northstar
and move James.WeaponReload outside the solo profile's mods directory.

Backup: Notes/backups/before-weapon-reload-20261024-220310 (real saves,
launcher, config, original test harness and hashes of unchanged components).
Source archive: source-snapshots/weapon-reload-1.0.0-20261024.zip, SHA256
37FDF7A830B5B7CCF1442B1463197DE9E6303C96F2FE879A00F773BB8B2168ED.

Test history: first isolated harness used literal primaryAttachment="NULL"
although the saved script field uses empty string. GivePilotLoadout rejected
that invalid attachment combination (22-05-23 log), leaving an incomplete
disposable test save. The next startup failed on its empty primary field
(22-07-38 log). Corrected the harness to empty attachment and restored ONLY
the isolated save from the real-save backup. Invalid test data archived in
Notes/tests/weapon-reload-20261024/invalid-test-save-before-reset.
The real save was untouched and hash-matched its backup during these tests.
Do not ship the test harness or copy its synthetic loadout JSON into real saves.
Third run (22-09-56) reached the checks with a valid test loadout, but the
harness used GetWeaponSettingFloat for damage_near_value, whose native type
is int despite the public documentation's float label. Changed that read to
GetWeaponSettingInt. No reload-addon source change was needed.

## Validation and deployment

Successful isolated log: map-cycle-test-profile/logs/nslog2026-10-24 22-11-53.txt.
All 8 combinations passed (four guns, Speedloader off/on) in an actual match:

| Weapon | Normal reload before -> after | With Speedloader before -> after |
|---|---|---|
| G2 | 2.2 -> 1.98 s | 1.54 -> 1.386 s |
| Alternator | 1.5 -> 1.35 s | 1.05 -> 0.945 s |
| R-201 | 2.2 -> 1.98 s | 1.54 -> 1.386 s |
| CAR | 1.8 -> 1.62 s | 1.26 -> 1.134 s |

All 8 normal/empty/checkpoint timing fields matched 0.9 of baseline. Tests
verified removal restores baseline, repeated application does not stack,
Speedloader/extended-mag attachments survive, damage/fire rate/air spread/
magazine are unchanged, and applying the modifier preserves loaded ammo.
15 bots had no james_solo_reload modifier. The optional forced bot-strip
branch was not reached because no bot held CAR; ownership cleanup is
implemented through OnPlayerInventoryChanged but that transfer scenario was
not separately exercised. Tests read native runtime settings, not recorded
animation durations. Successful run had no script/compile/error entries.

Test-only James.ReloadTest moved to Notes/tests/weapon-reload-20261024;
results.txt beside it. Only James.WeaponReload was copied into the real
solo profile. Installed files hash-match tested source. Real save hash still
matched pre-change backup immediately before the 22:14:19 normal launch.
Native v15 DLL remains 2A68A1CE0C0AB6294DE62C7E2742BE064C7ED086111C8251F1822FCCD22FA66C.

Normal-profile verification (nslog2026-10-24 22-14-20.txt):22:15:15 restored
902 named fields, Pulse Blade50% recharge active and Alternator reload0.90
active.22:15:16 UI cache mismatch count0. Observed16 occupied slots, teams
8/8, human plus15 bots. Zero logged script/compile/error entries; all902
saved field values still match the pre-change backup. Native DLL and bot
configuration were unchanged. Source git diff --check passed.
