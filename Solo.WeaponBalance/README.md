# Solo.WeaponBalance — role-specific pilot tuning v0.1

**Candidate only. OFF by default. Not merged, installed, or tested in a running game.**

This is the first *implementable* iteration following the [weapon-role assessment](https://github.com/BigCatMellow/TitanFall2/blob/research/weapon-roles-20261026/research/weapon-roles-20261026/GAP-ASSESSMENT.md) (draft PR #3). There is currently **no representative live hit-rate dataset** proving any of these changes necessary. We are testing targeted hypotheses, not claiming that the four weapons were conclusively over/underpowered.

The mod uses one named attachment, `solo_role_balance_v1`, with different weapon-specific KeyValues. It does not override base weapon scripts or make blanket class-wide changes. Source reference values in [balance-pass.json](balance-pass.json) come from a pinned third-party published multiplayer script snapshot, **not an inspection of the installed Northstar profile**. The effective runtime before/after values must be verified.

| Weapon (class) | Intended role and candidate change | Published reference → nominal trial |
|---|---|---|
| **Flatline** (`mp_weapon_vinson`) | Heavy, deliberate rifle: 20% less recoil scale **while ADS**; retain the slower 600 RPM/four-hit close body threshold and its distinctive hipfire | ADS kick scale min 1.5 → 1.2; max 2 → 1.6 |
| **Volt** (`mp_weapon_hemlok_smg`) | Controlled mid-range SMG: 25% less ADS recoil scale; do not raise its 660 RPM or damage to CAR values | ADS kick scale min/max 1.1 → 0.825 |
| **R-97** (`mp_weapon_r97`) | Volume-of-fire tracker: 30% less accumulated hipfire spread per shot **and** maximum extra spread, including airborne/crouched states; retain 1080 RPM, 20 near damage and 40 rounds | Kick per shot 0.5 → 0.35; kick cap 2.0 → 1.4 |
| **Spitfire** (`mp_weapon_lmg`) | Powerful suppressive/anchoring LMG: 20% slower **movement while ADS**, without harming lane-fire damage or reload | ADS move scale 0.35 → 0.28 |

The values above are simple KeyValue multiplier arithmetic, **not gameplay measurements**. Stock R-97 base hip spread is zero, so the R-97 changes affect spread *accumulation*, not first-shot accuracy. The Spitfire movement change is a movement multiplier, not a change from 0.35 to 0.28 seconds of ADS animation.

There are **no damage, RPM, ammo, aim-assist, ADS-in/out timing or bot-aim changes**. Flatline's 30 near body damage still takes four hits against a hypothetical 100 HP pilot; Hemlok's three 33-damage shots still total 99, and G2 is untouched. No unsupported cross-class buffs.

## Safety and application

- Mod convars are `solo_weapon_balance 0` and `solo_weapon_balance_bots 0` by default; having the folder installed and enabled does **not** change weapon stats until balance is opted into.
- Set `solo_weapon_balance 1` in a verified **isolated insecure solo** profile to test changes on the **local human pilot only**. Player inventory callbacks apply/remove the named attachment after spawn/loadout events; an existing held weapon may need a respawn or reselect after changing a convar.
- `solo_weapon_balance_bots 1` is a **separate, second-stage test**: it allows the same attachment on UID-0 bots while `solo_weapon_balance 1` is active. Bot weapon selection, usage and hit rates may not respond to viewkick/ADS the same way the human does. Bot mode stays off until validated; no other remote humans are selected.
- `ns_auth_allow_insecure` must also be enabled. A public/multiplayer profile is not an approved target. The existing four-gun reload add-on, tactical recharge, saving and bot aim are untouched. `SetMods` retains existing attachments.
- A separately proposed ADS-time trial (draft PR #2) targets the **Flatline** and G2. This candidate changes *different* Flatline fields but shares the weapon's KeyValue file location. **Do not run both without testing Northstar's KeyValue file merge and final effective fields**, just as the G2/reload combination needs validation.

## Isolated verification and acceptance

1. Confirm the private v18 overnight survey and workers are **actually finished** (not assumed from an old status/PID), that the isolated profile has fully restored, and that the Northstar core is the matching 1.31.14 build. Back up current isolated `mods`, `enabledmods.json`, convars and **current** saves. Never overwrite newer personal saves with survey baselines.
2. Install in the isolated test profile **only**, enable the add-on but leave both convars at 0. Verify game startup, KeyValue load, baseline weapon stats and the previous human reload/tactical mods with no application of `solo_role_balance_v1`.
3. Opt the local human in. For each target and its control (Flatline/R-201, Volt/CAR, R-97/CAR, Spitfire/R-201) test with the **same attachments, 100 HP, range, input and target movement**. Record at least 10 exploratory engagements per condition, comparing **off/on** effective weapon values and hit count, moving hit fraction, grouping, time to first accurate hit, and effective time to kill. Record experienced recoil/ADS movement separately from ideal body TTK.
4. Check **one weapon at a time** with other candidate edits logically isolated by equipping a control. Confirm death/respawn, weapon pickups, loadout swapping, toggling off + respawn, lobby/map transitions and existing reload/Speedloader. Confirm **no unintended impact** on other weapons, Titan weapons or saves. Profile should still be human+15 bots at aim 0.78.
5. Only after the human test succeeds, optionally enable `solo_weapon_balance_bots 1` in another isolated run. Validate bot attachments are applied, that bot behavior is not broken and existing aim 0.78 is unchanged. Never blend this run with old v18/map survey metrics.
6. **Reject** an edit if it fails to create a useful role advantage, erases a control weapon's purpose, cannot coexist safely with current add-ons, causes KeyValue load errors, or changes bot outcomes unpredictably. Keep the other weapons unchanged; don't compensate by adjusting damage/RPM by guesswork.

For immediate rollback set **both** convars to `0`, respawn/change the loadout, and confirm `WEAPON_BALANCE ... enabled=false`. For full rollback, close Northstar and remove/disable `Solo.WeaponBalance` in the isolated test profile. Do not restore older user saves. There has been **no production deployment** in this PR.

Relevant official Northstar docs: [weapon KeyValues](https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/), [weapon and KeyValue modding](https://docs.northstar.tf/Modding/guides/keyvalue/), [player inventory callbacks](https://docs.northstar.tf/Modding/reference/respawn/callbacks/).
