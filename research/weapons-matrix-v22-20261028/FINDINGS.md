# Weapon review of the v22 matrix — October28

Read-only review of29completed50point bot-only rounds, native2B08DE76... .
All raw source hashes were checked against the completed navigation metrics.
Only MAP_SURVEY_BEGIN..RESULT is analyzed, seeded by the actual recorder
context. Maps/navigation variants/repeats remain separate in the data. Human
played v20 results are in research/played-full-v20-20261028, not pooled here.
No weapon, aim, reload or recharge setting was changed for this review.

## Coverage, not a balance leaderboard

2710pilot death records;298qualifying100HP damage-to-death episodes;0recorder
errors in the analyzed windows. Eight roster primaries have credited lethal
outcomes and clean episodes:

| Gun | Credited enemy pilot kills | Clean health episodes |
|---|---:|---:|
| G2 |191|78|
| CAR |136|48|
| Hemlok |121|30|
| R-97 |109|24|
| R-201 |103|28|
| Longbow DMR |96|53|
| Flatline |80|19|
| Spitfire |55|18|

Counts combine navigation variants only to describe coverage; they do not compare
weapon power. Equipped time, actual firing opportunities, roles, ranges and
opponents differ. For example, G2 had4943live equipped observations and2090
visible-pilot combat observations; CAR3536and949respectively. Those are sampled
observations, not seconds, shots, exposures to an identical opponent or accuracy.
G2's larger kill total alone is insufficient for a damage nerf.

## Grenade self-safety is still the clearest combat defect

Bot-pilot frag outcomes:259enemy pilot kills versus513self-kills. Arc7/0,
Smoke14/0,Gravity3/0,Firestar7/0(enemy/self) in these windows. These smaller
ordnance counts do not establish equal use or comparative effectiveness.
Frags need throw feasibility/release/trajectory/escape diagnosis before bot
frequency or damage buffs. Do not lower the human grenade damage to hide the
bot decision problem. Prior v21 timing candidates failed their safety gate.

## Weapon-specific positioning needs investigation

Exact epoch/time/slot joins link live bot pilots, their actual equipped weapon,
updated combat state and visible engaged target to a simultaneously sampled
live pilot target. No actor identifiers are exported. Intended target distance
is XY distance, matching the controller's bands. It is not shot distance.

CAR628/949(66.17%) and R-97698/1081(64.57%)visible pilot-target combat samples
were beyond650units, the current ordinary controller's far band. G2495/2090
(23.68%)andLongbow413/1879(21.98%)were beyond their1350unit band. The rusher
personality already requests closing distance, so more aggressive intent alone
may not help if routes/cover/target changes prevent it from completing.

The configured bands are not damage falloff or a universal effectiveness limit.
Review whether the bands and closing/cover decisions are appropriate; do not
infer that all distant shots were bad or that shots occurred in each sample.
Charge Rifle holding observations exist, but it has no ordinary pilot band in
this analysis and is excluded from the primary range-policy comparison.

## TTK limits and next test

The298clean episodes measure first positive health damage to death, not
first-shot/trigger TTK. Strict per-round weapon/mod/config/range/hitgroup groups
are small (none reaches5samples in this screen). Repeated cases can be reviewed
further, but pooling conditions into one gun median would obscure differences.
There are0bot fire-sampling rows: the existing magazine sampler explicitly
excludes bots. We have no complete bot-shot/miss denominator or true accuracy.

Priority: fix bot grenade safety and investigate weapon-specific positioning,
then run controlled same-range, same-mod, same-hitgroup100HP weapon trials.
Keep current damage/RPM/reload/aim until those tests support a specific change.
This review launches no game and changes no installed profile or save.

Data: weapon-data.json retains map/guard/repeat/source hashes, qualified damage
span groups and split ordnance outcomes. weapon-positions.json retains the
separate sampled positioning metrics. Raw logs, actor IDs and saves stay private.
