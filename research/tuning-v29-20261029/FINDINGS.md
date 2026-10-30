# v29 tuning findings — 2026-10-29

**Source/test candidate; normal deployment unchanged.** The revised native is
82D039385FC8040ED103F64F3A013CF7401303714B3402ED36B77A327DF791BB.
Both new behaviors remain default-off. Aim0.78,0.8s firing warm-up, damage/RPM,
8v8 settings, human tactical0.5/reload0.9 and current saves were preserved.

## What changed and actually ran

Early clearance now recognizes ordinary255 traversal metadata and can inspect
blocked/walking pilots. Two DuckOnly hull confirmations, ground/near-level
eligibility, native-link handoff,2s limit and failed-location memory remain.
The revised Relic/WarGames lifecycle recorded one actual Duck-to-StandClear
recovery in0.4s, about25.7units of displacement, starts1/successes1/failures0.
This is execution evidence, not a map-wide efficacy result. Independent
clearance match cells did not run within this session's remaining time budget.

Owned-frag escape uses an additive actual-projectile feed, relative velocity,
checked ground/standing hulls, bounded movement and action handoffs. First
screening exposed rapid self-cancellation when moving away made the projectile
appear to depart. The revised controller uses departure only for entry and
320/352-unit entry/exit hysteresis. No grenade physics, fuse or damage change.
The sensor's age is time since first sighting, not verified fuse age.

## Revised native: two short matched map pairs

Goal 20 points per team,16 bots / 8v8, Full observer configuration. Relic ran control
then escape; WarGames ran escape then control. Frozen native/flags/readbacks,
fresh process each round. Four raw log hashes verified after cleanup. All four
completed with zero detected runtime errors. Snapshot: [screening-b.json](screening-b.json);
compact reviewed evidence: [screening-b-reviewed.json](screening-b-reviewed.json).

| Map | Frag self-deaths control → escape | Enemy frag deaths control → escape | Observed frags control → escape | Pilot low-progress samples control → escape |
|---|---:|---:|---:|---:|
| Relic |5 →3|5 →7|31 →36|1.40% →2.18%|
| WarGames |6 →3|5 →9|26 →40|1.90% →1.10%|

Combined counts:11 →6self-deaths,10 →16enemy deaths,57 →76observed frags.
Combat durations were306.6s control versus307.0s escape. Grenade use was not
suppressed, but throw rates changed with match behavior; counts are not a
randomized estimate of grenade safety. In particular, Relic navigation worsened
by0.78percentage points while WarGames improved by0.80points. Two short pairs
are insufficient for a broad difficulty/balance claim or a default rollout.

Initial6AB62D... Relic escape had30nearby restarts within0.3s and median0.10s
completed command span in122.3s. Revised Relic had5restarts/median0.55s in147.7s;
WarGames had11/median0.57s in159.3s. These are descriptive, different-run command
measurements, not independent incidents or proof of physical dithering. The
entry/continuation regression also reproduces the specific self-cancellation
mechanism. The initial build's two matches remain a separate cohort, never
pooled with the revised native. See screening-a-reviewed.json.

Match-window position checks found44usable, spaced native command windows;
43showed at least24units displacement.46were censored for missing/invalid
same-life snapshots. This supports sampled movement following commands, not
causal avoidance, increased grenade separation or confirmed safe escapes.
The whole-lifecycle movement report is separate: smoke-b-movement.json.

## Verification and operational state

- Revised five-phase control/on/respawn/off/lobby/new-map lifecycle passed,
  actual new flags and projectile/probe channels verified. validation-b.json.
- 126 Rust tests / 22 suites, migration/versioned-mod and preset fixtures passed;
  existing 109 Node tests plus four added regression checks passed (113 tests / 22 files).
  New tests cover continuation/entry boundaries, churn counting, real position
  followthrough exclusions and match-window boundaries. Locked offline build;
  original lock bytes E4F843... preserved. Antivirus unchanged.
- First script syntax failure was fixed; the absolute-velocity intermediate was
  intentionally stopped. Neither was counted as a passed lifecycle or match.
- Initial2round screen stopped cleanly for refinement. Revised4/6round screen
  ended at the time-budget margin after both pairs; remaining clearance cells
  were not attempted. No failed match attempts. No queue/game remains.
- Isolated native restored3077878B..., config/enablement restored, harnesses and
  awareness disabled per version. No historical save restoration. All11normal
  guarded files still match their current pre-test backup; normal native BC2... .

Notebook gaps remain flagged in all four revised matches. No new first-shot TTK,
accuracy, human K/D or skill-effect claim follows from these observer trials.
No visual spectator watching occurred. Raw sessions, account data, saves,
entity handles, meshes, reference SDK files and binaries stay private.

## Decision

Keep the new native/escape/crouch changes as an explicitly gated source candidate.
Preserve normal v23 play. Next efficacy work should isolate repeated Relic
clearance hotspots and examine route handoff after escape, then repeat the
paired map trials and get human combat feedback. Do not compensate for route
problems with aim/damage buffs or enable the rejected strict throw/height gates.
