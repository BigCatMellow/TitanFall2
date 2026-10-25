# Combat evidence review

Worker: complete
Queue: stopped_by_request

| Map | Report | Pilot-context quick reversals | Titan-context quick reversals | Cached combat snapshots while boarding |
|---|---|---:|---:|---:|
| mp_black_water_canal | complete | 23.37% | 41.48% | 49 |
| mp_colony02 | complete | 33.58% | 59.22% | 73 |
| mp_complex3 | complete | 23.11% | 59.09% | 57 |
| mp_crashsite3 | complete | 14.89% | 33.56% | 55 |
| mp_drydock | complete | 31% | 24.99% | 79 |
| mp_forwardbase_kodai | complete | 17.45% | 38.04% | 65 |

Pilot/Titan contexts use preceding actor snapshots up to2.1seconds old. These are percentages of target-switch events, not time spent confused or missed shots. A rapid A-to-B-to-A reversal is not automatically a bad decision. Older v16 logs do not mark combat sample freshness; boarding snapshots may contain cached ammo/tactic values. Individual JSON/CSV reports preserve missing context and these limits. No gameplay settings are changed.
