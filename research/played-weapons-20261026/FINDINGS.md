# Played-session weapon, movement and difficulty review

Session `20261026-201056-50da37bd`, four played maps, weapons-v19 build.
The recorder completed with533pilot death records,128qualifying health-damage
episodes and zero recorder/script/native error markers. This cohort includes
the human playing, unlike the historical22-map bot-only survey.

**Recommended first trial: improve safe combat movement while keeping current
aim, damage and firing warm-up.** Map-specific route fixes and a small defensive
ability mix are useful follow-ups. These findings are an offline review; no
gameplay settings, saves or installed plugin were changed for this review.

## What the player results establish

| Map | Recorded human pilot-victim kills | Recorded human pilot deaths | Main fatal weapon sources |
|---|---:|---:|---|
| Eden |14|2|R-20114|
| mp_lf_meadow |16|1|Volt15, electric smoke1|
| mp_lf_traffic |24|0|Kraber24|
| War Games |33|6|Spitfire26, SMR6, electric smoke1|

The33/6War Games result supports the reported difficulty gap. These are matched
lethal pilot-victim events, **not a full scoreboard reconstruction**. Titan
victims/deaths, minions and final team scores are outside the recorder. Do not
claim a total win rate or full K/D from these counts. A scoreboard/phase hook
would improve future round summaries.

## Weapons: useful measurements, insufficient grounds for a buff or nerf

| Gun / map | Qualifying human episodes | Descriptive median health-damage span | Observed span range | Median range of all damaging-source events |
|---|---:|---:|---:|---:|
| R-201 / Eden |3|0.234s|0.233–0.264s|958engine units|
| Volt / mp_lf_meadow |7|0.946s|0.377–3.694s|1455units|
| Spitfire / War Games |14|0.235s|0.118–4.020s|950units|

The medians above describe mixed ranges and critical-hit contexts within each
gun/map; **they are not matched weapon rankings**. Strict range/modifier/hitgroup
groups stay separate in [analysis.json](analysis.json). Time begins at first
positive health damage and includes pauses/movement between hits. It excludes
aim acquisition and misses, and is not first-trigger/first-shot TTK.

Volt was used at longer typical hit ranges than the R-201/Spitfire. Range,
different maps, target health/hitgroups, play style and small sample counts
confound a weapon-strength comparison. R-201/Spitfire's similar descriptive
medians also do not prove equal balance. Keep damage/RPM unchanged for now.

The Kraber registered24damaging events and24attributed pilot kills. That means
the recorded hits were lethal; it does **not** mean100%accuracy. Its projectile
events lack a verified modifier stack, so none qualified for clean weapon
timing. Keep them excluded rather than assigning the attacker's current gun to
an older projectile. Future projectile-origin metadata would improve this.

Only one bot-to-human death qualified for an isolated full-health/single-attacker
group: R-201,0–499units,0.567shealth-damage span. This is far too little to tune
human reaction windows.322of533death records had multiple attackers; exclusion
categories overlap. Shared kills are normal in8v8 and should not become fake
single-gun TTK samples.

## Combat movement is the strongest general lead

| Map | Visible pilot-engagement samples | Firing-range hold samples | Holds moving below50units/s | Holds with recent blocked-step increment |
|---|---:|---:|---:|---:|
| Eden |531|109|54.13%|42.20%|
| mp_lf_meadow |1051|399|45.61%|36.93%|
| mp_lf_traffic |1057|455|47.69%|45.49%|
| War Games |614|356|51.40%|41.85%|

These are sampled states/counter deltas, not a count of failed dodges or proof
that a blocked step caused a particular death. Against the human specifically,
45–50%of sampled holds were also below50units/s, although those subsets are small.
Hold totals include both `range_hold` and `reload_hold`; they are not counts of
shots fired or proof the bot was attacking during that sample.

The [installed movement path](../../bp_ort/src/bots/cmds/basic_combat.rs) replaces
the movement command with zero when the checked step is unavailable. The step
check also returns false while airborne; current diagnostics combine airborne,
wall and ground-edge denial. The [combat controller](../../bp_ort/src/bots/combat_decisions.rs)
otherwise uses a0.3side command with a predictable3.2sreversal schedule and a
bounded0.6sretreat. There is no health-aware cover selection in that decision
input. This supports investigating passive/blocked holds before raising accuracy.

First candidate: after a sustained denied lateral step, try a safely traced
alternative or a bounded route reposition. Preserve grounded/cliff checks,
cached trace budgets, two-buffer navigation and existing teardown safeguards.
Log denial reason/grounded state so airborne behavior and blocked corridors can
be evaluated separately. Keep ordinary strafe speed unchanged initially to
isolate the movement fix.

The existing0.8sfiring warm-up code and aim0.78should remain unchanged in that
trial. That source gate is not a measured player-visible reaction guarantee.
The aim is harder targets and better opportunities to engage, with the same
weapon lethality and firing rules.

## Some map problems recur, but do not explain the whole difficulty gap

| Map | Sustained navigation low-progress samples / live pilot samples | Fraction |
|---|---:|---:|
| Eden |69/1712|4.03%|
| mp_lf_meadow |0/1404|0%|
| mp_lf_traffic |1/1641|0.06%|
| War Games |132/4252|3.10%|

Eden's4096,-256,128cell recurred in15overlapping low-progress samples across4bot
slots, the same cell highlighted by the historical map study. War Games again
showed1664,-256,128(9samples/3slots), plus a larger current cluster at
-2944,-128,-64(21samples/8slots). The old and new percentages are not a controlled
before/after comparison.

104of132War Games low-progress windows had at least720degrees of cumulative yaw
travel over the sampled10–13swindow. None of the flagged windows on these maps
had Jump held for over20%of their recorded commands. The evidence points more
toward turning/recovery in those windows than sustained jump-button spam. It
does not show collisions, actual jumps or exact obstacles. Inspect those cells'
route choices; do not globally increase jumping or aim to address them.

Meadow/Traffic had almost no sustained navigation stalls while the human still
dominated their recorded pilot fights. Fixing the known map cells alone is
unlikely to close the difficulty gap.

## Abilities and organization

Across8983phase-window readiness observations, all sampled pilot tacticals were
Grapple and all ordnance was frag, with no nonzero shot-counter observation.
The current source explicitly generates no automatic requests for these default
classes. They are equipped but provide no demonstrated automated utility here.
Normal primary-weapon decision samples are overwhelmingly R-201, despite the
larger set of supported weapon profiles. The bots lack actual role variety.

A second, separate trial can give a small symmetric subset of bots already
supported defensive tacticals such as Stim/Phase. Preserve normal bot cooldowns
and the human's current50%recharge. Validate readiness, activation, movement,
respawn and map transitions before normal installation. Grapple route traversal
requires dedicated work; equipping it already does not implement that behavior.

Current team coordination spreads target claims and separates nearby teammates;
it does not implement tactical flanking or cover formations. The telemetry does
show multiple bots simultaneously seeing the human (max4–5across these maps), so
there is no justification for removing target-sharing protections or making
everyone focus the human. Better route angles and survivability are preferable
experiments to increased aim pressure.

## Evidence and reproduction

[Aggregate analysis](analysis.json) contains strict weapon groups, per-map
movement, native epoch/window associations and source hashes. Private full logs,
event streams, personal saves, names and account IDs were not published.
[Analyzer](../../tools/Analyze-PlayedWeaponSession.mjs) has four regression
fixtures covering continuity/turning, combat/death/gap boundaries, active-state
filtering, native target identity, phase trimming and repeated-map/event-ID reuse.

```powershell
node --preserve-symlinks --preserve-symlinks-main tests/played_session.test.mjs
node --preserve-symlinks --preserve-symlinks-main tools/Analyze-PlayedWeaponSession.mjs --session %USERPROFILE%/northstar-crash-audit/Notes/weapon-notebook/sessions/20261026-201056-50da37bd --profile %USERPROFILE%/northstar-crash-audit/local-test-profile --out research/played-weapons-20261026
```

Native windows begin at the frame before the recorder's Playing context and end
at the last pilot damage/death; exact winner/postmatch boundaries are unavailable.
Low progress requires the same sampled live pilot, continuous navigation states,
no gap>2.1s, and under50XYunits net displacement over10–13s. Windows overlap;
short unsampled deaths may be missed. No live visual observation occurred.
