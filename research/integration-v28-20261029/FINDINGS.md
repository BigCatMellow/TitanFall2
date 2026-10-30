# Four-hour integrated study: findings and decisions

42 of55planned30-point rounds completed across all15full-size planned maps.
The supervisor stopped normally at16:20:52EDT, before the16:27:48deadline, because
less than8minutes remained for a new round. No failed attempts or detected runtime
error markers. Isolated native/config/enablement were restored. Current normal
v23BC2... and all11guarded files remain unchanged; no game remains running.
This covers96,927pilot samples. Samples overlap;42rounds are not96,927independent
trials. The separate50-point preflight and controlled ability probes are excluded.

## Behavior screen

| Trial | What happened | Decision |
|---|---|---|
| Stall-target recovery | Actual cooldowns/target switching occurred. First matched pairs improved Eden0.427%to0.067% low-progress samples, but Relic worsened1.726%to2.730%; Complex/WarGames slightly worse. | No global rollout; investigate actual route completion after a switch. |
| Conservative frag safety | Four matched maps:182to27observed frags,28to13self-deaths,49to12enemy deaths. Combat exposure665sto732.6s. | Too restrictive for current use; fewer useful grenades without solving placement/escape. |
| Low-clearance approach | Zero logged duck starts, including its five individual trials and four combined rounds. No corner classified as an ordinary candidate anywhere. | Unexercised, not a navigation improvement. Validate native255/no-traversal semantics and eligibility before judging the action. |
| All-corner height trial | Eden0.427%to3.234% low-progress;WarGames2.807%to3.822%;Complex0%to0.956%. Relic slightly improved. | Keep off. This is the remote bot_corner_height_trial, not a change to the retained local repair. |
| Nearest pursuit | Coordination-off controls:Relic1.895%to1.660%,Complex1.941%to0.603%. Only two pairs. | Promising follow-up under its actual configuration; it does not change the normal coordination-on path. |
| Combined stall/frag/clearance | WarGames improved2.807%to0.589%, while Relic,Complex and Eden worsened. | No combined/global rollout from a single favorable map. |

All rates are overlapping pilot low-progress samples, not time-stuck or success
rates. One run per matched map/cell is weak causal evidence. Three repeat2Relic
candidate rounds completed without their repeat2baseline before time ran out;
those are excluded from paired comparisons. No coarse operational stop fired;
that permissive safety threshold is not a promotion or significance threshold.

The frag screen means about85%fewer observed projectiles,54%fewer self-deaths,
and76%fewer enemy deaths, despite longer combat exposure. The sampled subset is
small under the strict guard. Observed projectile matching can miss short-lived,
invalid-owner or near-boundary entities; multiple victims can share one grenade.
These counts support redesigning release/placement/escape rather than declaring
an improved per-throw safety rate or changing grenade damage/fuse.

Target memory generated120cooldowns across individual/combined rounds;117were
followed by a logged target switch within8s. That establishes execution and
temporal association, not117successful escapes. Ordinary corner classification
was zero across the whole screen, so changes in the nominal clearance cell must
not be attributed to an action that never started. Its repeat2Relic low-progress
rate reached5.60%with no active crouch, reinforcing the need for repeated controls.

Baseline-only map priorities are now WarGames2.81%,Colony2.16%,Relic1.73%, then
Rise1.12%andKodai0.97%. Eden's0.43% bot-only baseline is comparatively low with
its current local repair. This does not reproduce every human-induced vertical
pursuit problem; keep bot-only and played cohorts separate.

## Measurement correction

The first analysis wrapper filtered by engine t and accidentally discarded
WNOTE_GAP and diagnostic fault lines with no t field. The correction preserves
these records conservatively from the whole fresh-process log. A regression
failed on the old filter and now passes; all three integration fixtures and ten
frag/notebook concordance fixtures pass. No game/native behavior was changed.

All42raw-log hashes were verified before reanalysis. The corrected snapshot
retains641clockless gap warnings.1,159frag damage callbacks uniquely match
eligible notebook hits;1,147have consistent clean post-health decreases and12
lack clean post evidence. Every round now correctly says notebook_gap_review_required.
The old zero-gap/concordant status must not be used as coverage certification.
Raw logs and frozen per-round reports remain unchanged. Navigation, observed frag
outcomes and weapon-window aggregates were checked byte-for-byte equivalent as
JSON before/after correction. Missing evidence remains missing, not a negative
result. Clockless warnings cannot be precisely assigned to the match boundary.

## Abilities, weapons and next work

The separate1.1.0tactical probes passed all seven abilities with and without
PowerCell: Pulse Blade refill stays native; other six retain their intended
half-recharge behavior. Grapple was timed, repeated apply and removal tested,
and15bots stayed unmodified in each probe. The original1.0.0package was restored;
normal human50%preference stays as requested. Actual ability effects/range and
human fairness were not certified. The minimap fragment remains unintegrated.

No aim, firing warm-up, weapon damage/RPM or human modifier adjustment is
justified by this navigation/decision screen. Keep the current working baseline.
Next priorities: validate eligibility for trace-driven crouch on actual ordinary
corridors; implement and test projectile-relative escape/placement with real
release/trajectory feedback; rank reachable coordinated pursuits using measured
failure outcomes. Use repeated matched cases on WarGames/Colony/Relic before a
broader rollout. No new game run or normal deployment was started in this review.

Evidence: summary.json, final-screening30-corrected.json, validation.json and
tactical-validation.json. Raw paths, saves, actor/projectile handles and DLLs
remain private. The original55-job matrix is finished; do not resume historical PIDs.
