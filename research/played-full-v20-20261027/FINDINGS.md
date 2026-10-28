# First played Full v20 review

BT-7274 reported good tactical/grenade use and pilot movement. The telemetry
supports more active combat movement, varied weapons and real grenade damage.
**Keep the successful movement and skill trial; investigate frag self-kills
and Eden route stalls before increasing aim or damage.** No gameplay files,
saves or balance settings changed during this review. No visual watching occurred.

## Cohort and evidence

Completed normal-play session `20261027-190908-a8903c69`: Eden, Complex,
Meadow (Live Fire), Eden again. Startup metadata and command line identify
**Full**, native SHA256
`3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89`,
Northstar 1.31.14. Movement, proximity, height response, roster, defensive
tactics, skills and personality enabled; route guard, jump timing, crouch,
perception and viewkick sampling off. Aim remains 0.78, with the existing
0.8-second source firing warm-up and current human weapon/recharge changes.
No mid-session preset change is established by this review.

646 pilot death records, 96 qualifying single-attacker health-damage episodes;
zero recorder/fire errors and zero matched script/native/roster error markers.
This is separate from the v19 played baseline, controlled v20 smoke tests and
the historical v18 bot-only survey. Source-log and event hashes accompany
[analysis.json](analysis.json) and [capabilities.json](capabilities.json).
Raw logs, saves and session metadata remain private.

## Movement: substantially less stationary combat

The same sampled hold definition includes active visible pilot combat in
`range_hold` or `reload_hold`; below 50 engine units/s means nearly stationary.

| Round | Hold samples | Below 50 units/s | Median hold speed | Recent blocked-step sample fraction |
|---|---:|---:|---:|---:|
| Eden 1 |126|13.49%|139.1|11.90%|
| Complex |164|5.49%|160.5|3.66%|
| Meadow |406|5.67%|169.6|2.73%|
| Eden 2 |128|8.59%|166.3|7.09%|

In the earlier v19 session, Eden had 54.13% nearly stationary holds and 42.20%
with a recent blocked step (109 holds); Meadow had 45.61% and 36.93% (399 holds).
These same-map observations agree with the reported improvement. Different
weapons, personalities, target positions and play styles prevent a controlled
causal estimate. Samples are overlapping observations, not independent fights
or successful dodges. Actual jumping, wall-running and grenade trajectories
are not visible in this text telemetry.

All eight roster primaries appeared in native active-weapon samples and in
bot damage callbacks. The four intended weapon archetypes generated skill
requests. This establishes variety, not coordinated team tactics. Height
response found a candidate destination in 165 of 227 probes; arrival, survival
and protection from that point are not measured.

## Grenades: working, with a serious safety problem

Only bot **pilot** attackers and pilot victims are counted below. Self,
friendly and forced cases are kept out of opposing kill credit. Credit requires
matching round/event/victim/life, a zero-health post and a death callback.

| Source | Opposing damage callbacks | Enemy pilot deaths credited | Self pilot deaths credited |
|---|---:|---:|---:|
| Frag |78|37|103|
| Arc |15|2|0|
| Firestar |12|1|0|
| Gravity Star |3|0|0|
| Electric smoke |24|1|0|

All 132 opposing callbacks had a matching observation of health loss. This is
evidence that grenades affect fights, beyond just requesting a throw. These
sources account for 41 enemy pilot kills, none credited against the human.
They do not measure throws, hit probability, utility effects or damage to Titans.
End-of-frame health changes can include concurrent damage, so no attributed
damage sum is computed.

Frags also produced 176 self-damage callbacks and **103 matching self-deaths**:
19, 14, 46 and 24 by round. This is the strongest new defect signal. It does not
prove whether the cause is cooking, failed release, a nearby collision or running
back into a thrown grenade. Inspect the prepare/release/projectile lifecycle and
throw clearance/escape behavior in an isolated test. Preserve the successful
grenade behavior while correcting safety; do not compensate by increasing aim.

## Tacticals: separate requests from outcomes

4,023 allowed skill input starts: 1,727 tactical and 2,296 ordnance pulses.
These are not unique casts. Tactical reasons include Pulse reveal 810,
Cloak approach/disengage 212, Stim close-in/hurt 130, Holo decoy 120,
Phase escape 140 and A-Wall hold 239. Another 76 tactical requests use the
generic defensive fallback reason. Ordnance reasons are throw 2,242 and
smoke cover 54.

Readiness observations show resource levels below the current cost for Cloak
(2,035 samples), Stim (696), Holo (111) and Pulse (5), consistent with actual
consumption/cooldown. They do not count uses or establish tactical effectiveness.
Phase stayed at clip 200 and A-Wall at 100, with no below-cost samples;
their requests/brief equipped states do **not** establish successful activation.
Investigate those two with explicit activation/deactivation hooks before
claiming all tacticals work. Shot counters stayed zero even for grenades that
caused damage, so those counters are unsuitable as use evidence here.

## Navigation remains map dependent

Sustained low-progress windows were 296/3,327 live pilot samples on Eden 1
(8.90%), 13/1,589 on Complex (0.82%), 0/1,596 on Meadow, and 264/3,390 on
Eden 2 (7.79%). Eden's movement problem has not disappeared. These fractions
are descriptive; the v19 Eden value was 4.03% under different conditions.

The old Eden hotspot at `4096,-256,128` recurred in 111 overlapping windows
across eight slots in the second Eden round. A different first-round cluster
near `-1792,2816,320` had 91 windows across two slots, plus 47 in its neighboring
cell. Of the 560 Eden low-progress windows, 329 included at least 720 degrees
of cumulative turning. None exceeded a 20% jump-command fraction. This supports
route/recovery investigation, not a global jump increase.

Per-round diagnostics group 429 stall incidents; 238 (55.5%) have a link/jump
corner classification or partial route, while only two are duck-only fits.
Classification depends on the documented jump encoding and is a lead, not
proof of physical cause. Prioritize Eden link handling and bounded local
recovery over enabling global crouch. `capabilities.json` trims diagnostics to
played epoch/windows; `nav-diagnostics.json` separately covers the entire log,
including post-round activity, and reports 432 incidents.

## Difficulty and next steps

Recorded human pilot-victim kills/deaths were 0/2, 13/1, 26/4 and 8/6.
The combined 47/13 (3.62) is not proof that the roughly 3:1 balance target is
met: human participation, weapons, Titan activity and maps differ. This logger
excludes Titan victims and does not reconstruct scoreboards or win rate.
Do not interpret the first round's zero kills as representative combat skill.

Retain aim, warm-up, weapon damage and human buffs. Next isolated work should:

1. Instrument grenade prepare/release/owner distance and prevent unsafe frag use.
2. Validate Phase and A-Wall activation with outcome hooks.
3. Inspect the two Eden route clusters and test bounded link/recovery changes.
4. Recheck the same maps and weapons with the human playing before balance changes.

## Reproduction

From the repository root, using the private session/profile paths relative to
the audit parent:

```powershell
node --preserve-symlinks --preserve-symlinks-main tools/Analyze-PlayedWeaponSession.mjs --session ../Notes/weapon-notebook/sessions/20261027-190908-a8903c69 --profile ../local-test-profile --out research/played-full-v20-20261027
node --preserve-symlinks --preserve-symlinks-main tools/Analyze-PlayedCapabilities.mjs --session ../Notes/weapon-notebook/sessions/20261027-190908-a8903c69 --profile ../local-test-profile --out research/played-full-v20-20261027
```

The capability extension verifies the original played-analysis hashes. Five
regression checks cover reused event IDs, victim/life matching, self/friendly/
forced/Titan separation, zero-counter resource evidence and epoch/window trimming.
