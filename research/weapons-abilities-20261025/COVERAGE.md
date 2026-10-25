# Recorded weapon coverage

Phase windows match the map review. These are v16 BOT_COMBAT cache names joined to live bot-pilot frames, not verified current inventory/ammo. No shot, hit, damage, tactical-ready or ability-activation dataset is present. See FINDINGS.md.

| Map | Cohort | Phase | Live pilot samples | With combat cache | Cached weapon names |
|---|---|---|---:|---:|---|
| mp_black_water_canal | controlled-complete | Current all-map queue | 4754 | 3610 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_colony02 | controlled-complete | Current all-map queue | 4414 | 3633 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_complex3 | controlled-complete | Current all-map queue | 4283 | 2624 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_crashsite3 | controlled-complete | Current all-map queue | 4256 | 3165 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_drydock | controlled-complete | Current all-map queue | 4406 | 3384 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_forwardbase_kodai | controlled-partial | Current all-map queue | 4232 | 3340 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_eden | controlled-complete | Earlier fresh-process queue | 4785 | 3877 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_glitch | controlled-complete | Earlier fresh-process queue | 4325 | 3301 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_angel_city | controlled-complete | Earlier fresh-process queue | 3766 | 2574 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_eden | controlled-complete | Earlier fresh control | 4914 | 3818 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_lf_meadow | controlled-complete | First map of earlier cycle survey | 3822 | 3822 | mp_weapon_rspn101 |
| mp_eden | played | Played 2026-10-25 | 1630 | 1372 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_thaw | played | Played 2026-10-25 | 1935 | 1549 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_eden | played | Played 2026-10-24 | 2304 | 2085 | melee_pilot_emptyhanded, mp_weapon_defender, mp_weapon_rspn101 |
| mp_lf_meadow | played | Played 2026-10-24 | 1431 | 1431 | mp_weapon_rspn101 |
| mp_lf_meadow | played | Played 2026-10-24 | 1502 | 1502 | mp_weapon_rspn101 |

## Cohort totals

- controlled-complete: 10 recordings; 43725 live pilot snapshots, 33808 matched combat-cache snapshots.
- controlled-partial: 1 recordings; 4232 live pilot snapshots, 3340 matched combat-cache snapshots.
- played: 5 recordings; 8802 live pilot snapshots, 7939 matched combat-cache snapshots.

## Cached names by cohort

| Cohort | Cached weapon identifier | Matched pilot snapshots |
|---|---|---:|
| controlled-complete | melee_pilot_emptyhanded | 196 |
| controlled-complete | mp_weapon_defender | 1990 |
| controlled-complete | mp_weapon_rspn101 | 31622 |
| controlled-partial | melee_pilot_emptyhanded | 16 |
| controlled-partial | mp_weapon_defender | 137 |
| controlled-partial | mp_weapon_rspn101 | 3187 |
| played | melee_pilot_emptyhanded | 34 |
| played | mp_weapon_defender | 263 |
| played | mp_weapon_rspn101 | 7642 |
