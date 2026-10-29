# Frag damage ↔ WeaponNotes concordance trial (2026-10-29)

**Read-only, source-only candidate. No installed game, bot behavior, damage, DLL, normal profile or save was modified.**

## Why this additional cross-check exists

The additive `BT7274.FragDamageProbe` (default disabled) emits one `BT_FRAG_DAMAGE` record per positive *bot-pilot frag damage callback*. The existing `Solo.WeaponNotes` mod already emits `WNOTE_CONTEXT`, `WNOTE_HIT`, `WNOTE_POST`, `WNOTE_GAP` and `WNOTE_DEATH`, with strict logic for observed health changes and pilot deaths. Raw callback counts alone can disagree due to mod enablement, callback order, missing recorder context, source labels or invalid/missing events. The cross-check is an **investigation of logger concordance** before any claims about grenade safety.

`tools/Compare-FragNotebook.mjs` reads **one private Northstar log containing both channels**; it does not merge different files or guess clock offsets. It writes only summary counts.

## Exact matching rules

For a `BT_FRAG_DAMAGE` callback to match an independent `WNOTE_HIT`, all of the following must hold:

1. A valid preceding `WNOTE_CONTEXT map=mp_...` establishes the current recorder segment, and the frag callback uses the **same map**. Any callback before a context or on a mismatched map is *unscoped*.
2. Both records have **exactly equal Squirrel `GetEncodedEHandle()` attacker and victim values**. These are script-side encoded handles, not native bot slots. Signed encoded handles are supported; invalid `-1` is not.
3. `WNOTE_HIT` declares `gun=mp_weapon_frag_grenade`, `akind=bot`, `vkind=bot|human`, `atitan=false`, `force=false`, valid nonzero teams and a valid victim life; the victim relationship (self/friendly/enemy) agrees with the frag callback.
4. Callback timestamps differ by **at most 0.05 engine seconds**. This is only a provisional same-callback observation window, not a synchronized clock contract; calibrate in a controlled runtime test.
5. The candidate graph is strictly **one-to-one**. If one frag record matches multiple notebook hits, or multiple frag records compete for one hit, the records are `ambiguous` and never counted as verified matches.

A uniquely matched callback counts only as `uniquely_matched`. It counts as `post_health_decrease_consistent` only when the same notebook event, victim and life has an un-gapped `WNOTE_POST`, 0–0.5 seconds later, with nonnegative health **below** the recorded pre-damage health. `fatal_notebook_record_consistent` additionally requires post-health zero and a matching `WNOTE_DEATH` within 0.05 seconds. These are **coincident independently logged records**, not proof the frag callback alone caused the decrease or that its projectile caused a kill; concurrent damage can contribute.

`WNOTE_ERROR`, `WNOTE_GAP`, and `BT_FRAG_DAMAGE_ERROR` are surfaced as reliability problems, not silently ignored. An empty or unmatched log cannot prove that no frag activity occurred.

## Run safely on the local PC

From the latest `main` with this PR *reviewed and intentionally checked out* in a **clean** working tree:

```powershell
node --test tests/frag_lifecycle_probe.test.mjs tests/frag_damage_probe_source.test.mjs tests/frag_notebook_compare.test.mjs

node tools/Analyze-FragLifecycle.mjs --log "<PRIVATE_NSLOG.log>" --out "<PRIVATE_SUMMARY.json>"

node tools/Compare-FragNotebook.mjs --log "<PRIVATE_NSLOG.log>" --out "<PRIVATE_CONCORDANCE.json>"
```

First validate the standalone add-on alone with `bt7274_frag_damage_probe=0` then `1`, with normal `solo_weapon_notes=1` and an ordinary match entering the `Playing` state. Confirm both logger families appear in the **same** chronological NS log. Use the isolated `map-cycle-test-profile` only; preserve normal/current saves, DLL and installed `_grenade.nut`. Record hashes, mod versions, map, convars, enabled flags, timing and any script errors locally.

If identical callbacks regularly have more than 0.05 seconds separation, **do not expand matching globally without first checking whether two independent events are being conflated**. If `WNOTE_HIT gun` names differ from the source, document them before changing the classifier. If `WNOTE_CONTEXT` is absent, stop and fix the recorder/instrumentation setup before interpreting match statistics.

The analyzer deliberately does **not** join the native `BOT_FRAG_INPUT` slot, `DamageInfo_GetInflictor` to a launched projectile, or infer explosion distance/fuse behavior from a damage callback. Those require separate runtime identity and physics validation. Any source override for `_grenade.nut` is a higher-risk optional experiment, **not** part of this concordance test.

## Validation status

Ten pure-JavaScript tests exercise independent post/death concordance, ambiguous rapid hits, competition, map/context isolation, signed handle privacy, WNOTE_GAP and life mismatches, mismatched gun/attacker evidence, missing safety fields, probe failure and notebook errors. They passed in the V8 evaluation harness against the committed sources. The actual standalone Node CLI, Squirrel compilation and played Northstar validation have **not** been performed here.

**Output is aggregate and private-safe; raw private NS logs, encoded handles, player metadata, saves, DLLs and any exact event timestamps stay local.**
