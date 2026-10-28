# v22 matrix findings — October28

29of32planned50point rounds completed across8maps;14complete matched pairs and
one unmatched Homestead guard-on round. The queue stopped safely for its time
budget at16:16, not a game error. Missing: Homestead repeat2guard0 and both
Eden repeat2rounds. Do not count the unmatched round in paired comparisons.
All29child results are complete/profile_restored and their raw log SHA256s
were checked against the metrics.0detected runtime error markers.132.865active
round minutes. Normal9guarded files/saves unchanged; normal and isolated native
hashes both confirmed restored v20. No game remains from this experiment.

## Outcome: map-specific signal, no global deployment

Lower means fewer overlapping sustained low-progress pilot samples. Per-map
percentages combine only complete pairs' numerators/denominators; pair directions
are also retained in comparison.json. Different round durations are not ignored.

| Map | Complete pairs | Guard off | Guard on | Interpretation |
|---|---:|---:|---:|---|
| War Games |2|3.74%|2.21%|Lower in both repeats; strongest follow-up signal|
| Eden |1|5.94%|3.84%|Promising single pair; second pair missing|
| Complex |2|0.24%|0.90%|Higher in both repeats; do not enable globally|
| Relic |2|1.28%|1.09%|Small decrease in both; practical effect uncertain|
| Black Water Canal |2|0.70%|0.51%|Mixed pair directions|
| Angel City |2|0.51%|0.51%|Mixed directions; aggregate essentially unchanged|
| Homestead |1|0.23%|0.77%|Higher in first pair; unmatched repeat excluded|
| Meadow |2|0%|0%|No eligible holds recorded; does not exercise the new rule|

7pairs had a lower rate,5higher,2equal. Reversed order/repeats help comparison
but are not randomization or proof of a causal effect. Two repeats are not
confidence intervals, and overlapping pilot samples are not independent trials.
No candidate stop threshold was triggered; that coarse safety threshold is not
a deployment gate or evidence all regressions are negligible.

## Key diagnostic: the guard is usually interrupted by replanning

Across29rounds,7533guard starts,7522explicit ends:7466replan and56advance.
About99.26%of observed ends are replans.11starts lack an observed end and stay
censored. These counts are not independent bot failures or physical climb
success rates. Replans can legitimately follow target changes. The useful
finding is that a static height rule usually does not survive to an advance.

Next investigation: record WHY each replan happened (target changed, forced
recalculation, or remaining list empty) and whether the current waypoint was
still pending. The current follower replans when nav.path_points is empty,
although next_target_pos can still hold a popped corner. Test preservation of
that active waypoint under bounded progress/watchdog checks; do not broadly
cache stale routes or change traversal bytes/mesh ABI. Then repeat War Games
and finish Eden, with Complex and a lower-stall map as regression checks.

Keep the default guardOFF and normal v20. Do not promote on a pooled overall
rate: improvements on War Games/Eden would hide the consistent Complex increase.
No weapon, aim, cooldown or human difficulty adjustment follows from this
navigation-only bot cohort. Existing weapon/grenade raw notes remain private
for separate analysis. The earlier played two-round findings remain separate.
