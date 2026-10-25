# What the deeper decision review establishes

Existing v16 data supports a focused incoming-target investigation and a smaller
watchdog correction to test later. It does not justify increasing aim, damage or
ability strength. No game was launched, plugin changed or map queue resumed.

The [reproducible analysis](../../tools/Analyze-DecisionContext.mjs) examines the
same 16 phase-filtered recordings as the [map review](../trends-20261025/FINDINGS.md).
[Methods and limits](METHODS.md), [per-round summary](SUMMARY.md), [data](rounds.json).

## Overhead targets are brief, rapidly descending observations

| Cohort | Overhead bot snapshots | Deduplicated target frames | Target bursts | Bursts showing rapid descent | No adjacent follow-up |
|---|---:|---:|---:|---:|---:|
| Completed controlled, 10 recordings | 541 | 268 | 185 | 169 (91.35%) | 16 |
| Partial Kodai, 1 recording | 38 | 21 | 14 | 13 (92.86%) | 1 |
| Played, 5 recordings | 106 | 52 | 36 | 31 (86.11%) | 5 |

Across the corpus, all 213 bursts with an adjacent target-coordinate pair show
at least one >=500-unit Z drop. The other 22 lack that follow-up; they do not
show persistent stationary bad coordinates. All bursts contain one or two high
frames, with a maximum observed span of two seconds. Actual unsampled duration
is unknown. This refines the earlier concern: the observed issue is repeated
brief selection during descent, not evidence of long sky fixation.

Every high target is absent from the same-frame alive player-entity list,
including the adjacent follow-up. Combined with the descending trajectories
and the source's live pet-Titan candidates, incoming auto-Titans are the leading
explanation. Exact entity/transit classification is still missing.

Several bots can select the same target during a burst: up to six distinct bots
in the current exports. That is six over the sampled burst, not proof all six
looked simultaneously. For example, fresh-control Eden target 262713 is selected
by slots 2/4/6/8/10/16 at 425.02–427.02 game seconds; target Z falls from
11542.6 to 7620.6, then 2418.1 at the next observation. Its 11 bot snapshots
represent two high target frames, not 11 independent incoming entities.

The source ranks candidates by horizontal distance, includes live pet Titans,
and also uses horizontal range for the visibility check. A later fix should
reject an ineligible incoming target before both visible selection AND pursuit
fallback. Changing only the visible range risks redirecting the same mistake
into navigation. Prefer a verified existing engine/script transit predicate;
the 5000-unit analysis threshold is not a validated gameplay rule. Preserve
nearby grounded Titans and reachable elevated pilots.

## The watchdog can inherit time spent fighting

The native helper records a movement anchor and reports a stall after three
seconds without 80 units of XY progress. The clock is checked when following a
path. Visible combat can skip path following without clearing the anchor.
Returning to pursuit at nearly the same position can therefore immediately
report `no_progress`, even if that time was spent intentionally engaging.

The [engine-independent reproduction](watchdog-repro-result.json) confirms
that helper behavior: a four-second call gap triggers; a fresh anchor does not;
100 units of movement does not; a real three-second stationary navigation
sequence still triggers. This is a reproducible timer-context weakness, not
proof of how many recorded recoveries are false alarms.

The strict log filter finds five compatible cases with the last engagement
snapshot within 0.25s of the recovery: Colony two, Crash Site one, Drydock one,
and played Exoplanet one. There are seven at <=0.5s and 21 at <=2.1s; those are
nested sensitivity counts, not additional cases to add together. Source excerpts
are retained in [strict examples](strict-recovery-examples.json).

For example, Colony slot 10 holds exactly the same position at 163.02, 165.02
and 167.02 while visibly engaging, with path/recovery counters unchanged. At
167.05 it emits `no_progress`. Unobserved navigation between snapshots remains
possible. Explicit recovery totals include all actor contexts, so a false-alarm
percentage cannot be calculated from the five candidates.

A later isolated candidate could age the watchdog only across active navigation
or reinitialize its anchor when returning from intentional non-navigation.
Tests must preserve genuine obstruction recovery, retreats/boarding, clock resets
and map teardown. No timer/behavior change was made in this review.

## What this changes in our priorities

1. Incoming-target eligibility now has repeatable trajectory evidence across
   controlled and played maps, rather than one unusual example.
2. Preserve Eden/Complex as separate route/collision investigations. The strict
   watchdog filter found zero close-timing Eden cases; this narrow test neither
   explains that hotspot nor rules out other timer effects.
3. Keep the watchdog issue as a bounded candidate with a pure-code reproduction;
   establish runtime impact before treating it as a major fix.
4. Validate diagnostic v17 when game testing is authorized. Current sampled
   actor/ammo limitations still constrain target-continuity and reload analysis.
5. Retain 8v8, aim 0.78, current saves and the existing human recharge/reload
   adjustments. Broad weapon or ability changes still lack outcome evidence.

Analysis fixtures, all 16 overhead-count consistency checks and the native
research reproduction pass. No new runtime stability or gameplay benefit is
claimed. The next game test remains paused until requested.
