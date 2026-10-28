# Completed Full v20 baseline — October28

All22supported maps have a valid75point16bot8v8 round with inactive observer.
This combines the9recovered initial rounds and13completed continuation rounds,
using the same validated v20 native3077878B.../bridge9C437198.../core1.31.14.
Collection finished08:39October28; this analysis is separate from the live v22
50point A/B experiment. No historical v18 or human-played rounds are pooled.

122.98minutes active round time,40859live pilot samples,0detected runtime error
markers in the completed logs. One round per map is screening, not a stable
ranking or independent sample population. Exact per-map denominator, sampled
window, core and source-log hash are in rounds.json; REVIEW.md has all22rows.

| Map | Live pilot samples | Sustained low-progress samples (%) |
|---|---:|---:|
| Complex |2475|8.12|
| War Games |3637|5.91|
| Eden |2180|3.76|
| Black Water Canal |2347|1.19|
| Homestead |1336|0.37|
| Meadow |1134|0|

Complex's large hotspot cluster near(-8448,-2048,576) and(-8320,-2944,576/640)
means it should be treated as a bot-only stress comparison, despite looking
better in earlier played contexts. War Games retains its recurring1664,-256,128
cluster. The rates do not prove mesh defects, corner skipping, difficulty or
why a bot failed; map/hull/traversal/controller context still needs investigation.

This supports the varied-map v22 plan: more than one problem map, alongside
Meadow/Homestead lower-rate controls and mixed Canal/AngelCity/Relic conditions.
The50point rounds use a different native and score goal; compare matched v22
switch0/1 pairs rather than claiming a before/after against these75point rows.
Low progress uses overlapping10–13second navigation/recovery/boarding windows;
short unsampled deaths can be missed. No video or causal improvement claim.
