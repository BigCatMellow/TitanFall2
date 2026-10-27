# Automatic weapon notebook

First played-session results are now available in the
[weapon/movement/difficulty review](../../research/played-weapons-20261026/FINDINGS.md):
four maps,533pilot death records,128qualifying episodes, including24human-attacker
episodes. Reference stats below remain separate from those live observations.

Launch **Northstar - Solo Bots (8v8)**, or `Play-Solo-Bots.cmd`, as usual. The
launcher starts a local, read-only damage recorder alongside the game. No manual
timestamps are needed. This is text telemetry, not video or audio recording.

Each launch gets its own folder under
`%USERPROFILE%\northstar-crash-audit\Notes\weapon-notebook\sessions`:

- `NOTES.md`: readable summary, refreshed every 15 seconds and after exit.
- `summary.json`: grouped damage spans, individual deaths and exclusion reasons.
- `events.jsonl`: structured pilot damage/life/death events for later reanalysis.
- `session.json`: core/native version, installed add-ons and session conditions.

Use the solo shortcut for automatic collection. Launching Northstar directly
does not start the notebook collector. Results stay local; no automatic upload.
The recorder reads the owned session's log and does not change weapons, bots,
health, cooldowns, saved loadouts or progression. Close the game normally to
finish the session. A stopped collector cannot stop the game.

## What the numbers mean

[Reference table](REFERENCE.md) and [catalog](catalog.json) cover the 30 selectable
pilot weapons. Pinned reference damage, nominal RPM, magazine, range, handling
and provenance stay distinct from the v19 runtime-field validation and from
observed combat. Scalar ideal TTK is only calculated for the listed steady
weapons under explicit assumptions. Other firing mechanisms need dedicated
models. Never substitute inherited/null fields with zero.

Live matches measure **first positive health damage to death**, not first-trigger
or first-shot TTK. A damage event is not necessarily one shot. Misses, shots
fired, ADS state and accuracy are not available from these hooks. Range is
engine units; numeric hitgroups/critical scales are retained without guessed
headshot labels. Titans are outside this initial pilot-only notebook.

Qualifying episodes begin at full 100 HP and end in an observed lethal event
with matched before/after health. Shared attackers, weapon/mod/config changes,
unknown modifier stacks, injured starts, observed healing, unaccounted health
loss, friendly/self/forced damage and incomplete sequences are excluded from
the clean groups. Full health returning between fights starts a new episode.
The checks cannot prove the absence of unobserved shields, healing or buffs.
Small samples remain exploratory, with sample count and min/median/max shown.

Groups keep map, session mode, weapon, human/bot actor kinds, actual modifiers,
configuration, first-damage range bucket and hitgroup/critical contexts separate.
Targets may move across range bands during an episode; per-hit range and velocity
remain in the raw structured records. Synthetic
validation has its own `controlled_validation` mode and never joins normal play.
Use the same build and conditions for comparisons. No automatic balance changes
are driven by these measurements.

## Implementation and validation

`Solo.WeaponNotes` registers damage-final, death and respawn callbacks and reads
nonlethal health at the end of the frame. The Node collector accepts only structured lines beginning with
`WNOTE_`, ignores general/authentication logs, and writes anonymous entity/life
identifiers, not account IDs or names. Source logs and private saves stay local.

Hook semantics are based on the official
[callback reference](https://docs.northstar.tf/Modding/reference/respawn/callbacks/)
and [DamageInfo reference](https://docs.northstar.tf/Modding/reference/respawn/native_server/damageinfo/).
The separate isolated test harness deliberately injects damage to validate
attribution and health sequencing; it is never enabled in the normal profile.
See [validation record](VALIDATION.md) for actual test results and limitations.

Offline checks:

```powershell
node --preserve-symlinks --preserve-symlinks-main tests/weapon_notes.test.mjs
node --preserve-symlinks --preserve-symlinks-main tests/weapon_notebook.test.mjs
node --preserve-symlinks --preserve-symlinks-main tools/Build-WeaponNotebook.mjs
```

## Opt-in rounds and view-kick sampling (Solo.WeaponNotes 1.1.0, source only)

Both default to `0`; with both off the recorder behaves exactly as 1.0.0.

- `solo_weapon_notes_fire 1`: samples the local human's active weapon each frame
  and logs `WNOTE_FIRE` (rounds = magazine decreases, ADS rounds when the zoom
  query works, reloads) per gun/modifier/config. The analyzer adds `accuracy`
  rows as observed-expenditure proxies, matched by actor/life/time/config.
  These are not accuracy or guaranteed lower bounds; magazine polling can miss
  rounds. Invalid/over-unity denominators produce no ratio. It has its own error budget (`WNOTE_FIRE_ERROR`) and cannot disable the
  damage notebook.
- `solo_weapon_notes_viewkick 1`: logs `WNOTE_KICK` per firing burst (eye-angle
  drift from the burst start). Includes aiming input; only meaningful in a
  controlled test from a fixed position without mouse movement.

Not compiled or run here; validate in the isolated profile first. See
research/bot-capability-20261027/README.md for the blinded per-weapon protocol.

Review correction: magazine polling now captures actor/life/time/config windows.
It reports `pilot_hits_per_observed_round` only for valid matched windows;
`pilot_hit_fraction` is null because an exact shot denominator is not proven.
This proxy is not accuracy or a guaranteed lower bound. Missing intervals,
reload ambiguity, invalid counts or over-unity results invalidate the ratio.
Sampler runtime/API validation is still required before using it in trials.
