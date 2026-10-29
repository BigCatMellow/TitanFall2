# BT7274.FragDamageProbe — safer first-stage grenade investigation

**Source-only opt-in add-on. Never install into the normal profile.**

This additive server mod uses the existing Northstar
`AddDamageFinalCallback("player", ...)` mechanism. The project's working
`Solo.WeaponNotes` add-on already uses this callback for its independent
post-damage life/death notebook; this probe does not modify that add-on.

- Its new convar `bt7274_frag_damage_probe` is **0 by default**.
- It operates only on an insecure local solo server (`ns_auth_allow_insecure`),
  only on bot pilot attackers (`GetUID() == "0"`) and non-Titan pilot victims,
  only for `eDamageSourceId.mp_weapon_frag_grenade`, and only for positive damage.
- A single `BT_FRAG_DAMAGE` event per qualifying **damage callback** records
  time, map, encoded attacker/victim/inflictor handles, self/friendly/enemy
  classification and the reported damage. These private handles remain in
  the local NS log and must not be published.
- A one-time `BT_FRAG_DAMAGE_ERROR` records a caught diagnostic failure
  without interfering with the existing damage pipeline.
- **Does not** mutate DamageInfo, projectile code, grenade fuse, physics,
  offhand inputs, bot damage, target selection or installed weapon balance.

This does not prove that health decreased by the reported amount or that a
kill occurred: the existing `WNOTE_POST` and `WNOTE_DEATH` callbacks
provide that independent attribution under their documented restrictions.
`DamageInfo_GetInflictor` may be a weapon instead of the projectile. Do
not equate its handle with a spawned grenade until a controlled test proves
the identifier semantics. This module does **not** track throws or explosions.

## Local test gate

1. Read `AGENTS.md`, `docs/LOCAL-TEST-HANDOFF-2026-10-29.md`, and
   `research/bot-ai/FRAG-LIFECYCLE-INSTRUMENTATION-2026-10-29.md`.
2. Run `node --test tests/frag_lifecycle_probe.test.mjs tests/frag_damage_probe_source.test.mjs` and review
   `mod.json` against the installed Northstar 1.31.14 format.
3. Back up the isolated `map-cycle-test-profile` and its mod enabled state.
   Install this **new** add-on only there. Verify default-off yields zero
   events and no initialization errors or gameplay change.
4. Set `bt7274_frag_damage_probe 1` only for controlled pilot frag cases.
   Compare its own event counts with independent WeaponNotes positive-health
   loss and death callbacks in the same validated local window.
5. Observe friendly and self-damage cases separately; turn the probe off
   and confirm normal behavior, map transitions, round restart and removal.
6. Keep private logs and saves local. Run
   `node tools/Analyze-FragLifecycle.mjs --log <PRIVATE_NSLOG> --out <PRIVATE_REPORT.json>`
   for aggregate-only diagnostic counts and error flags. Do not join different
   identity namespaces without explicit validation.

The *more invasive* generated `_grenade.nut` override in this PR is
**optional and a second-stage experiment only**. If this standalone callback
provides enough evidence, do not replace the original Northstar grenade script.

No Squirrel compilation, Northstar startup, runtime callback coexistence or
in-game damage attribution is claimed in this source pass.
