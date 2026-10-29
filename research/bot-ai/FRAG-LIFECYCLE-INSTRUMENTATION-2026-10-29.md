# Frag lifecycle instrumentation candidate — 2026-10-29

**Status: source-only, opt-in, NOT installed, NOT a validated safety fix.**

The played Full v20 session measured **103 bot frag self-deaths** against **37 enemy pilot deaths** credited to bot frags. Those are verified **damage/death** outcomes, but do not tell us why: a bad fuse/cook, failed toss, a grenade spawning inside geometry, a delayed death-drop, or a bot running back into a grenade remain distinct hypotheses.

This experiment helps distinguish _input requests_ from _the grenade script reaching preparation, launch and callback stages_. It makes **no balance, physics, damage, AI or installed-game modification** on its own.

## Source of truth and hooks

The public Northstar server source [`_grenade.nut`](https://github.com/R2Northstar/NorthstarMods/blob/main/Northstar.CustomServers/mod/scripts/vscripts/weapons/_grenade.nut) implements:

| Event | Where inserted | What it establishes | What it does **not** establish |
| --- | --- | --- | --- |
| `prep` | After `Grenade_OnWeaponTossPrep` sets `startChargeTime` | Bot frag's preparation code ran | Grenade spawned or was thrown |
| `spawn` / `spawn_null` | Immediately after `FireWeaponGrenade(...)` returns | A server-side grenade entity was returned / was not returned | Projectile movement, actual release success, explosion, hit |
| `release_callback` | After `Grenade_OnWeaponTossReleaseAnimEvent` invokes `Grenade_OnWeaponToss_` | Release callback completed | Every previous request produced a viable projectile |
| `cancel_drop_callback` | After `Grenade_OnWeaponTossCancelDrop` invokes toss | Cancel-drop callback completed | That an ordinary throw occurred |
| `forced_release_request` | Immediately after `ForceReleaseFromServer()` | Engine force-release method was requested | It was actually processed or completed |
| `death_drop` | After `HACK_DropGrenadeOnDeath` calls `Grenade_Launch` | The death-drop branch returned a projectile value | It exploded, harmed the owner, or caused death |

For server output only, the helper is guarded by the existing default-off `bot_frag_input_probe` convar and filters for bot-owned `mp_weapon_frag_grenade` weapons. The private raw `BT_FRAG_STAGE` record includes map, time, stage, encoded owner/weapon/projectile handles, elapsed cook time, remaining launch fuse and the current owner-to-projectile gap. The helper has no gameplay side effects other than diagnostic logging overhead.

**Important:** the Rust `BOT_FRAG_INPUT` logger records an offhand command issued for a native bot **edict/slot**, while Squirrel uses encoded entity handles. The input and lifecycle events must **not** be joined by raw equality until identity mapping and timing are explicitly validated. The existing `WNOTE_HIT/WNOTE_DEATH` callback chain proves damage/death under its own rules, but does not yet identify an exact grenade entity. This candidate therefore does not claim per-projectile death attribution.

Public Northstar [entity documentation](https://docs.northstar.tf/Modding/reference/respawn/entities/) documents grenade entities, `GetThrower`, `GrenadeExplode`, `GetGrenadeFuseTime`, and `ForceReleaseFromServer`. [Weapon key-values](https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/) document grenade fuse and owner-damage flags. These interfaces are background context, not evidence that this candidate observes explosion itself.

## Prepare an isolated, uninstalled patched copy

The local Windows agent must first locate the **exact file used by installed Northstar 1.31.14** and preserve a verified backup. The `tools/Prepare-FragLifecycleProbe.mjs` command takes the local source file, checks seven known signatures **exactly once**, refuses already-instrumented/unknown source, and writes **a new candidate only** with exclusive creation (`wx`). It refuses to overwrite its input and never modifies game installation files directly.

```powershell
node --test tests/frag_lifecycle_probe.test.mjs

node tools/Prepare-FragLifecycleProbe.mjs `
  --source "<PRIVATE-LOCAL-NORTHSTAR-SOURCE>\_grenade.nut" `
  --out "target\frag-lifecycle-candidate\_grenade.nut"

node tools/Analyze-FragLifecycle.mjs --log "<PRIVATE-NSLOG.log>" --out "<PRIVATE-REPORT.json>"
```

**Not a standalone mod.** The generated file must be integrated as a *separate isolated server script candidate* by the local agent, using the correct script override/load order for the installed build. Do not place it in the normal profile; do not overwrite stock `Northstar.CustomServers` in place. Only enable `bot_frag_input_probe 1` for matched controlled rounds. If the seven anchors differ from installed source, stop and review manually; never automatically patch a similar-looking file. Native bot plugin must be loaded so the convar exists. Do not enable `bt7274` changes in public servers.

## Analysis and safety rules

The read-only `tools/Analyze-FragLifecycle.mjs` reports per-map event totals and **distinct logged spawn handles** (with a 2,048-entry per-map cap), duplicate handles, `spawn_null`, death-drop callbacks, and two **hypothesis inspection bins**: residual fuse below 0.25 seconds and owner-to-projectile gap below 120 units at spawn. Those bins are **not validated danger thresholds**. Almost every grenade spawns relatively near its owner; no outcome is implied.

The report excludes owner/weapon/projectile identifiers, coordinates, raw lines and any attempted owner/kill joins. It now separates observed map/time segments on map changes and engine-clock rollback greater than 0.5 seconds, so common projectile handles reused in later rounds are not automatically mistaken for duplicate spawns. Truncated logs, smaller out-of-order clock changes, map resets without a detectable boundary and script/runtime errors can still distort counts; retain the original private logs for local debugging. Neither a disappearance nor a missing projectile callback is proof of a successful detonation. A caught diagnostic exception emits a single `BT_FRAG_PROBE_ERROR` marker and the analyzer sets `probe_status=probe_error_review_required`. If there are no valid `BT_FRAG_STAGE` events, it instead sets `probe_status=no_valid_stage_events_cannot_infer_no_grenades`, because the probe might be disabled, missing, or simply unexercised. Any probe fault is a **stop-and-review** signal; an empty report is not a negative gameplay observation.

## Required local testing sequence

1. Execute Node tests and inspect the generated private copy. Compare its output diff against the exact installed baseline. Ensure only seven hook sites and one helper were added.
2. Check Squirrel syntax, VM/server-only behavior, default-off state, load order and the original game profile's script integrity **before** loading the isolated candidate. Restore the known-good v20 if any native/script error occurs.
3. Run a smoke round with `bot_frag_input_probe 0` and verify zero `BT_FRAG_STAGE` records. Then turn it on in the isolated profile with otherwise unchanged loadout/AI and confirm `prep`, `spawn`, and/or `spawn_null` events without duplication or performance regression.
4. Use controlled frag throws to separately exercise normal release, cancel/drop, long cook and death-drop. Check exact event ordering, projectile handles and measured remaining fuse; no cases may be assumed to work until observed.
5. Link this to existing `BOT_FRAG_INPUT` and `WNOTE_HIT/WNOTE_DEATH` **only after** independently validating actor identity namespaces, map/epoch boundaries and actual projectile-to-damage association. Until then compare aggregate evidence channels independently.
6. Compare matched Eden, War Games, Complex and Meadow rounds, with the same bot count, tactics, other flags, duration and player exposure. Quantify frag *self-deaths and enemy deaths* per equivalent played exposure and inspect whether the hazardous behavior is late cooking, death-drop, near geometry or re-entry into blast radius.
7. Confirm mod disable, removal of isolated candidate, map transition and rollback to the original script; leave normal saves and installation unchanged. Publish a sanitized findings report and separate fix PR rather than automatically changing the frag safety logic.

## Verification performed remotely

- Seven exact source anchors are present **once each** in public NorthstarMods `_grenade.nut` on 2026-10-29; the actual generator was also applied in memory to that public source and produced one helper plus six additive call sites, without deleting original lines.
- The generator and analyzer's nine pure-JavaScript regression cases passed in the repository's remote JavaScript evaluation harness. **The standalone Node CLI test command and Windows 1.31.14 Squirrel compilation, DLL build, isolated launch or gameplay observation have not been executed here.** The injected helper uses an exception guard and emits a one-time sanitized error marker if a diagnostic call fails.
- The base Git rollback `backup/pre-bot-ai-20261029` and merged v20/v21 source remain untouched. This is an independent **draft** experiment.

**Important deployment warning:** An entire third-party `_grenade.nut` source override is significantly riskier than a standalone observer. If Northstar 1.31.14 cannot safely load an isolated override of this script with the correct include semantics and update compatibility, **do not deploy the patched copy**. Report that blocker and pursue a validated event callback or plugin hook instead.
