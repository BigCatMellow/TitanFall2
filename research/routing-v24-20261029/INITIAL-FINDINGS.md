# Initial frozen routing screen

Seven completed 50-point, 16-bot Full rounds have been reviewed as of07:26EDT.
All have zero detected runtime-error markers. Both study chunks stopped after a
completed round for isolated native experiments; profile restore and all ten
normal-file guards passed. This is seven rounds across five maps, not a completed
14-map sweep or an eight-hour run. The normal deployment remains unchanged.

| Map | Global route trial | Pilot low-progress samples | Observed frags | Matched self deaths | Matched enemy deaths |
|---|---:|---:|---:|---:|---:|
| Relic | off |2.305%|83|15|11|
| Relic | on |1.142%|89|12|15|
| War Games | on |2.567%|81|14|14|
| War Games | off |2.281%|72|14|8|
| Angel City | off |0.645%|80|16|20|
| Colony | off |1.322%|70|11|8|
| Crash Site | off |0.158%|67|6|16|

Relic's single pair is encouraging, while War Games is mixed. No candidate stop
threshold was reached, but that is an operational safeguard rather than evidence
for promotion. Samples overlap; these are not independent failure rates, matched
human difficulty tests or a guarantee of complete map traversal. Global routing
can affect Titan routes; this low-progress measure only includes pilots.

Grenade outcomes differ by map even in the baseline. Crash Site recorded six
matched self-deaths and16enemy deaths; Colony11and8. This supports investigating
launch/exposure context before a blanket frag cooldown or damage change. One
War Games trial kill callback was unmatched; all other listed joins were matched.
Multiple victims can share a projectile, outcomes can overlap, short-lived or
invalid-owner projectiles can be missed, and near-end observations are censored.

Weapon windows are collecting attack callbacks/shot parameters and magazine
expenditure separately. They do not yet provide a validated accuracy or first-shot
TTK denominator. Keep current weapon power, aim and firing warm-up fixed while
improving movement and safety. Played rounds remain separate from this observer
cohort and from the default-off v25/v26 native traversal prototypes.

Evidence: screening-first-two-pairs.json and screening-three-variety-maps.json.
The public status.json is a generated latest-chunk view, not a cumulative count.
Private study batches hold raw logs and exact process/normal-profile guards.
