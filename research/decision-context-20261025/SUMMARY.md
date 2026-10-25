# Offline decision-context summary

Stable v16 only; same phase windows as the trend review. Target bursts are deduplicated selection observations, not unique Titan drops. Recovery contexts are hypotheses, not confirmed false alarms. See [methods](METHODS.md).

| Map | Cohort | Overhead bot snapshots | Target frames | Target bursts | Bursts with observed descent | no_progress events | Possible stale context, <=0.25s / <=0.5s / <=2.1s |
|---|---|---:|---:|---:|---:|---:|---:|
| mp_black_water_canal | controlled-complete (Current all-map queue) | 138 | 63 | 41 | 39 | 239 | 0 / 0 / 0 |
| mp_colony02 | controlled-complete (Current all-map queue) | 98 | 52 | 33 | 33 | 376 | 2 / 2 / 2 |
| mp_complex3 | controlled-complete (Current all-map queue) | 0 | 0 | 0 | 0 | 240 | 0 / 0 / 1 |
| mp_crashsite3 | controlled-complete (Current all-map queue) | 2 | 1 | 1 | 1 | 102 | 1 / 1 / 2 |
| mp_drydock | controlled-complete (Current all-map queue) | 24 | 18 | 14 | 13 | 228 | 1 / 2 / 3 |
| mp_forwardbase_kodai | controlled-partial (Current all-map queue) | 38 | 21 | 14 | 13 | 191 | 0 / 1 / 3 |
| mp_eden | controlled-complete (Earlier fresh-process queue) | 86 | 41 | 31 | 30 | 571 | 0 / 0 / 0 |
| mp_glitch | controlled-complete (Earlier fresh-process queue) | 4 | 4 | 4 | 1 | 208 | 0 / 0 / 0 |
| mp_angel_city | controlled-complete (Earlier fresh-process queue) | 102 | 49 | 34 | 31 | 172 | 0 / 0 / 0 |
| mp_eden | controlled-complete (Earlier fresh control) | 87 | 40 | 27 | 21 | 515 | 0 / 0 / 1 |
| mp_lf_meadow | controlled-complete (First map of earlier cycle survey) | 0 | 0 | 0 | 0 | 46 | 0 / 0 / 3 |
| mp_eden | played (Played 2026-10-25) | 26 | 13 | 10 | 8 | 65 | 0 / 0 / 0 |
| mp_thaw | played (Played 2026-10-25) | 26 | 15 | 12 | 9 | 120 | 1 / 1 / 1 |
| mp_eden | played (Played 2026-10-24) | 54 | 24 | 14 | 14 | 283 | 0 / 0 / 2 |
| mp_lf_meadow | played (Played 2026-10-24) | 0 | 0 | 0 | 0 | 19 | 0 / 0 / 2 |
| mp_lf_meadow | played (Played 2026-10-24) | 0 | 0 | 0 | 0 | 23 | 0 / 0 / 1 |

## Cohort totals

- controlled-complete: 10 recordings; 541 overhead bot snapshots, 268 target frames, 185 target bursts; 169 bursts (91.35%) show an adjacent >=500-unit Z drop. 169 bursts have an adjacent target-coordinate pair; the rest lack follow-up. 2697 no_progress events; 4 / 5 / 12 possible stale contexts at the three frame-age thresholds.
- controlled-partial: 1 recordings; 38 overhead bot snapshots, 21 target frames, 14 target bursts; 13 bursts (92.86%) show an adjacent >=500-unit Z drop. 13 bursts have an adjacent target-coordinate pair; the rest lack follow-up. 191 no_progress events; 0 / 1 / 3 possible stale contexts at the three frame-age thresholds.
- played: 5 recordings; 106 overhead bot snapshots, 52 target frames, 36 target bursts; 31 bursts (86.11%) show an adjacent >=500-unit Z drop. 31 bursts have an adjacent target-coordinate pair; the rest lack follow-up. 510 no_progress events; 1 / 1 / 6 possible stale contexts at the three frame-age thresholds.
