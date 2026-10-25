# Review while James plays — 2026-10-25

The automated map queue is paused by explicit user request. Five trials in
that queue finished; Kodai was intentionally interrupted at its last recorded
141–98 after745.1s. That closure is not evidence of a spontaneous crash.
All14 current-trial restoration checks passed. Both report workers finished
their six reports and exited. remaining-maps.json lists17 trials to repeat
or finish, starting with Kodai; resuming needs a NEW batch/current save
baselines and another user request. Do not restart the old runner.

James's regular stable-v16 solo session launched12:03:26EDT on Eden,
fullscreen,1human+15bots/8v8. The log confirms902 named loadout fields restored.
No diagnostic build, aim setting, navigation file or gameplay tuning was
deployed. The new normal game may legitimately update saves as James plays;
do not restore old survey save backups over those updates.

## Map evidence collected

There are10 completed recordings covering9 distinct maps, plus partial
Kodai. These span separate frozen-v16 runs, not one complete all-map survey.
Percentages below are flagged two-second live pilot samples, not percentages
of bots or counts of unique stuck incidents. The heuristic excludes deliberate
engage/range holds; a flagged sample looks back about10seconds. Random
encounters and one trial per map limit comparisons.

| Map | Stalled pilot samples | Assessment from these recordings |
|---|---:|---|
| Crash Site |0.42%|Few scattered stalls; good comparison map|
| Angel City |0.85%|Few localized stalls; earlier full200-point round|
| Drydock |1.09%|Scattered stalls; close172–170 timed round|
| Black Water Canal |1.24%|Scattered short stalls|
| Glitch |1.36%|Movement comparatively healthy; some edge/height cases|
| Colony |1.84%|A few localized/longer episodes, not an Eden-scale shared hotspot|
| Complex |2.54%|52 of109 flagged samples at one cell, all from slot11; investigate that bot/area|
| Eden |6.23–8.38% across two fresh controls|Repeated shared obstruction aroundX4120,Y-300; highest priority for route investigation|
| Meadow |0.10%|Earlier small-arena TDM round; different geometry/encounter mix|
| Kodai, partial |1.16%|Interrupted by user; not a completed map result|

Complex's longest contiguous flagged stall span was36s and Colony's22s.
Those spans describe runs of the heuristic after its lookback, not exact
continuous immobilization durations. Eden's repeated point near
(3765,-253,150), reached from bots stuck aroundX4120, remains stronger
evidence of a shared route/collision problem than a map-wide vertical
tolerance defect. See REVIEW-20261025-NAVIGATION.md for exact coordinates.

## New target-selection finding

The source's distance() helper uses XY only. Team candidates use this value
both for ranking/close-threat classification and the3000-unit visibility
range check. Auto-Titans from get_pet_titan() are included when alive, with
no transit/vertical-distance check in that enumeration.

Recorded example, Canal slot9: at game time67.02 it selected a normal-height
enemy. At69.02 it selected target393331 atZ11127 while the bot was atZ-99.6;
the same target descended toZ7205.1 at71.02 andZ2002.6 at73.02. All three
selections were marked visible/engage. At75.02 it selected another target.
This is consistent with an incoming Titan, but the old log lacks an explicit
entity-kind/transit-state marker. It does prove that the selection considered
targets far outside a3000-unit three-dimensional radius.

Among visible/engage pilot snapshots, the selected target was over5000units
above the bot in8.49% on Canal,7.11% on Colony,7.00–7.29% on Eden and6.82%
on Angel City. The rates were0.14% on Crash Site and0.31% on Glitch. These
are selected-target observations, not proven wasted shots or exact time
fractions. Cached ammo does not establish firing during those observations.
map-comparison.json and overhead-target-example.json preserve inputs/results.

A useful small candidate is eligibility/range handling for distant incoming
Titans. It must cover BOTH visible selection and unseen-pursuit fallback:
changing only the raycast range could turn a sky engagement into an equally
unhelpful pursuit. Confirm entity/transit status first, preserve nearby
shootable threats, and compare landing transitions on an isolated trial.
Do not apply a universal height blacklist or aim increase from these data.

## Other bot improvements to evaluate, in order

1. Validate target eligibility/transit handling above. This has direct
   source/log evidence and affects combat organization across several maps.
2. Inspect Titan-specific target continuity. Prior-frame Titan quick-reversal
   rates were about59% on Colony/Complex versus23–34% for pilot contexts;
   Drydock reverses that pattern (Titan24.99%,pilot31%). This is map-dependent,
   and switches alone are not confirmed mistakes. Use exact actor/current
   shootability diagnostics before a short retention trial. Do not revive
   the rejectedv14 failed-goal/cache changes.
3. Reproduce Eden's obstruction, then Complex slot11's area, with selected
   polygons, projected start/end points, traversal metadata and physical
   collision traces. Avoid global extra jumping or broad navmesh edits.
4. Evaluate combat step alternatives. Current range-hold logic stops movement
   if its chosen side/backstep trace is blocked; it does not try the opposite
   side in that same decision. A bounded opposite-side retry with the same
   wall/ground clearance checks could reduce stationary holds. It needs a
   separate real ledge/wall test; preserve safe stops when both sides fail.
5. Run a representative weapon matrix after navigation baselines. These
   default pilot combat trials only observed R-201s; they do not validate
   shotgun/sniper/SMG/projectile/heat weapon behavior. Human loadouts remain
   separate and protected. Keep population8v8 and aim0.78 fixed.

## Prepared diagnostics and limits

observation-v17-candidate is built and saved, NOT DEPLOYED. It adds exact
pilot/Titan labels and current-command combat freshness only.34 tests and a
47058-decision differential comparison pass; real isolated runtime and map-
transition checks remain. Older combat snapshots can be stale during boarding
or Titan encounters, so empty-magazine/reload observations alone are not
confirmed reload failures. No gameplay change is justified by those alone.

No live visual watching is claimed. The desktop capture connection was
unavailable; user screenshots confirmed the named Computer Use plugin/skill
was not in their visible catalog. Local bot-follow recording with automatic
log-time matching remains future setup; no recorder has been installed.

The old Meadow→Eden600-FX-handle failure did not reproduce in two fresh Eden
controls, but fresh processes do not test cross-map resource accumulation.
Do not call the FX issue fixed. There is no need to alter the user's current
game while conducting this archived-data review.
