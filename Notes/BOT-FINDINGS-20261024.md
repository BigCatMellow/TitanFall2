# Findings from longer v12 rounds

Read after refreshing the full Glitch and current Eden exports on 2026-10-24
around 15:12. Both use v12, coordination 1 and 15 bots. These are different
maps and encounters, not a controlled comparison of builds.

| Measure | Glitch | Eden |
|---|---:|---:|
| Snapshot duration | 462 seconds | 346 seconds |
| Bot observations | 3336 | 2458 |
| Low-movement observations | 14 | 44 |
| Crowded observations | 13 | 78 |
| Failed route queries | 424 | 283 |
| Recovery attempts | 61 | 70 |
| Target changes | 2305 | 2145 |

Low-movement observations are repeated two-second samples after the stall
heuristic fires, not counts of distinct stuck events. Native alive samples
were 2368 on Glitch and 1912 on Eden. Do not compare raw totals without
duration, combat state and map context.

Eden: 22 of the 44 low-movement samples fell in the same coarse
256-by-256-by-128 cell, lower corner (1536,1792,128). The cell is a diagnostic
hotspot, not a known named landmark. 43 of the 44 were pilots; only one was
a Titan. Slots 4, 5 and 10 accounted for 16, 9 and 9 samples respectively.
Glitch had 10 pilot and 4 Titan low-movement samples, more dispersed.
The logs cannot establish which wall, ledge or navigation edge caused this.

Source inspection: failed routes already have a one-second retry guard.
The progress watchdog clears routes and tries 1.2 seconds of avoidance.
Target ranking uses distance, team pursuit pressure and continuity, without
remembering per-target route failures. Thus a bounded failure memory and a
different escape waypoint are plausible next experiments, not proven fixes.

Suggested order, not implemented by this analysis:

1. Escalate repeated no-progress recovery and temporarily avoid a failing
   route/goal. Measure repeat visits to the Eden hotspot.
2. Use route-failure history when selecting unseen pursuit targets; preserve
   immediate visible-threat priority and expire any penalties.
3. Investigate target churn and path-request reasons before changing the
   commitment duration or recalculation rate globally.
4. Tune ally spacing only after testing narrow passages and different floors.

Keep 8v8 and aim error 0.80 while evaluating navigation. More unstructured
rounds are not a prerequisite to the first experiment. A short screen clip
of the hotspot would help distinguish a ledge, wall, teammate blockage or
bad steering, since replay data lacks terrain/video. Do not promise full
OctBots navigation compatibility based on this telemetry.

Reports: sessions/nslog2026-10-24_14-13-53 and
sessions/nslog2026-10-24_15-06-09. No bot code/settings changed in this review.
