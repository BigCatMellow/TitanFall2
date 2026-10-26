# Which weapons actually need adjustment? — evidence triage

**Implementation update:** the targeted human trial is now installed after
effective-field, ownership and lifecycle checks. The lack of a representative
hit-rate/feel study remains; hypotheses below are not proven balance findings.
[Rollout record](../../Notes/candidates/weapons-v19-20261026/README.md).

**Decision on 2026-10-26:** No weapon is yet *proven* underperforming in the installed solo game. Do **not** issue blanket buffs. The reference numbers do identify specific potential gaps that are worth checking, in a defined order.

This is a follow-up to [the 30-weapon role review](FINDINGS.md), using its [pinned third-party reference-stat snapshot](reference-stats.json). The existing v16/v18 research has extensive bot-decision samples, but the weapon samples were dominated by R-201 and do **not** contain a representative shot/hit/damage matchup study. Do not infer accuracy, actual effective TTK or win rates from those recordings.

## Evidence convention

- **REFERENCE-VERIFIED:** a direct field in the pinned weapon script snapshot (not necessarily active in James's current profile).
- **CALCULATED:** a transparent arithmetic comparison from those fields, under stated assumptions.
- **HYPOTHESIS:** a possible violation of the intended weapon role; a test target, **not** a finding of poor balance.
- **UNKNOWN:** requires the actual game, attachment/mod stack, recoil/crosshair behavior, bot weapon implementation and/or user feedback.

For bullet weapons only, our simplified calculation is: `shots = ceil(100 / listed body damage)`, `ideal sustained TTK = (shots - 1) / nominal shots_per_second`. It models a hypothetical 100-HP target, first hit at t=0, all hits landed, no headshots, no movement, no ADS/latency, and steady cadence. It **must not** be used for Hemlok bursts, Devotion ramp, Kraber rechamber, pellets, multiple simultaneous projectiles, charges, explosives, or anti-Titan damage. A weapon's near/far damage bands may start/end at different distances, so cross-weapon “far” numbers are **not** necessarily the same range.

## Targeted findings

### 1. Flatline versus R-201 — does heavier damage pay off?

| REFERENCE-VERIFIED | R-201 | Flatline |
|---|---:|---:|
| Near / far damage | 25 / 17 | 30 / 20 |
| Rate | 13.5/s | 10/s |
| Magazine | 24 | 30 |
| Base standing hip spread | 2.0 | 1.0 |
| Hip spread added per shot | 0.5 | 0.5 |
| Stock ADS-in | 0.25 s | 0.25 s |
| CALCULATED near hits / ideal TTK | 4 / 0.222 s | 4 / 0.300 s |
| CALCULATED far hits / ideal TTK | 6 / 0.370 s | 5 / 0.400 s |

**HYPOTHESIS:** Flatline's heavier per-bullet impact does not create a nominal body TTK advantage against 100 HP at either listed band; its advantages instead appear in magazine, base hip spread and per-hit reliability. Those may be sufficient. Test **moving/hipfire accuracy and missed-shot recovery**, not just stationary DPS.

**Only if the role is failing:** try a small, **weapon-specific** improvement to recoil consistency/recovery or the relevant spread behavior. Check falloff separately. Do not immediately raise damage from 30 to 34: 3 × 34 = 102 would cross to a three-shot close-range kill. Do not assume the existing 25%-faster ADS trial fixes this particular issue.

### 2. Volt versus CAR — is the slower SMG meaningfully more controllable?

| REFERENCE-VERIFIED | CAR | Volt |
|---|---:|---:|
| Near / far damage | 25 / 13 | 25 / 15 |
| Rate | 14.1/s | 11/s |
| Magazine | 30 | 33 |
| Base standing and running hip spread | 0 | 0 |
| Hip spread added per shot | 0 | 0 |
| Deploy time | 0.66 s | 0.40 s |
| CALCULATED near hits / ideal TTK | 4 / 0.213 s | 4 / 0.273 s |
| CALCULATED far hits / ideal TTK | 8 / 0.496 s | 7 / 0.545 s |

**HYPOTHESIS:** The Volt's slower theoretical kill does not automatically mean it's worse: it has faster deployment, modestly better listed far damage and a slightly larger magazine. Its intended reward may be controllable sustained accuracy. Both use the same named recoil spring in these references, but single viewkick coefficients do **not** describe the entire pattern.

**Only if the role is failing:** compare repeated *real* mid-range hit rate and target-acquisition time. If the Volt cannot generate a meaningful precision/consistency advantage and feels redundant, investigate recoil/shot-spread behavior first. Do not copy CAR's RPM or increase Volt damage before seeing that evidence.

### 3. R-97 versus CAR — can its volume overcome the extra spread growth?

| REFERENCE-VERIFIED | CAR | R-97 |
|---|---:|---:|
| Near / far damage | 25 / 13 | 20 / 12 |
| Rate | 14.1/s | 18/s |
| Magazine | 30 | 40 |
| Base standing hip spread | 0 | 0 |
| Hip spread added per shot | 0 | 0.5 |
| CALCULATED near hits / ideal TTK | 4 / 0.213 s | 5 / 0.222 s |
| CALCULATED far hits / ideal TTK | 8 / 0.496 s | 9 / 0.444 s |

**HYPOTHESIS:** Its near ideal TTK is very close to CAR, while the R-97's 40 rounds and extremely rapid firing provide a different sustained-fire niche. The accumulating hip spread may make that advantage hard to realize while tracking a moving pilot.

**Only if the role is failing:** measure shot grouping/hit fraction as the magazine empties while moving and tracking. If excessive bloom defeats the intended high-volume role, a modest *R-97-only* spread-kick adjustment is more appropriate than generic damage/RPM buffs.

### 4. Spitfire versus R-201 — investigate potential strength, not weakness

| REFERENCE-VERIFIED | R-201 | Spitfire |
|---|---:|---:|
| Near / far damage | 25 / 17 | 35 / 25 |
| Rate | 13.5/s | 9/s |
| Magazine | 24 | 80 |
| Stock ADS-in | 0.25 s | 0.30 s |
| Base standing hip spread / added per shot | 2.0 / 0.5 | 1.5 / 1.5 |
| CALCULATED near hits / ideal TTK | 4 / 0.222 s | 3 / 0.222 s |
| CALCULATED far hits / ideal TTK | 6 / 0.370 s | 4 / 0.333 s |

**HYPOTHESIS:** This weapon is powerful on paper in a stationary lane, with major capacity and ranged-damage advantages; its balancing costs may be slower presentation, movement/recoil and shot growth. The near/far bands are **not** identical in distance, so the far TTK comparison is illustrative, not a matched-range claim.

**Action:** No buff. Test whether cover-holding is rewarded without the Spitfire also dominating mobile close engagements. A reduction may be warranted only if the runtime evidence shows the intended weaknesses are ineffective.

### 5. G2 and Hemlok — preserve critical breakpoints

- **G2 REFERENCE-VERIFIED:** 40 near / 35 far at 5.5 shots/s; its three-hit body threshold against 100 HP survives both bands. Standing hip spread 5.5 helps preserve a precision-aim requirement. **No damage buff justified.** The 25%-ADS trial (0.25 → 0.1875 s) might make mid-range aim more responsive but also removes some of its close-range handling cost. Test it independently.
- **Hemlok REFERENCE-VERIFIED:** three-shot burst with 33 near damage each: **3 × 33 = 99**. One fully landed body burst will leave a hypothetical 100-HP pilot alive. Raising each bullet to 34 would make that one-burst lethal. This is a **design breakpoint**, not evidence of a defect. Test actual cadence/hit consistency first; do not inadvertently cross it with a generic damage increase.
- **Alternator REFERENCE-VERIFIED:** 35 near body damage at 10 shots/s and a 20-round magazine; it already gets a three-hit close-range threshold, unlike the four-hit CAR, with a lower capacity and slower rate. **No buff indicated from static data.** Keep the Alternator/Volt classname fix in draft PR #1 separate.

### 6. Specialty weapons — no simple ranking yet

Devotion's ramp (5 → 15 shots/s in 1.75 s), Cold War's charge + four-shot burst, Kraber's rechamber, L-STAR heat and projectile time, shotguns' pellet patterns and anti-Titan lock/explosion/armor mechanics invalidate naive nominal-RPM/body-damage leaderboards. No defensible tuning order can be inferred without purpose-built scenarios and actual hit/impact timings.

## Evidence-based queue, not a buff list

| Priority | Question | Fair comparison | What would justify a change? | First variable to consider |
|---|---|---|---|---|
| 1 | Does Flatline's heft beat the R-201 at anything that matters? | Same target, ranges and movement; unmodified ADS first | Flatline repeatedly loses the intended hit/recovery or range advantage | Flatline-only recoil recovery or spread, **not** damage breakpoint |
| 2 | Does Volt gain enough precision/response to offset CAR's cadence? | Same mid-range target; include weapon swap | Volt is inferior in both achieved hit-rate and engagement response, with no useful niche | Volt-only controllability, **not** copied RPM |
| 3 | Does R-97's volume remain useful through a magazine? | Same moving target and extended spray versus CAR | High bloom makes sustained track worse despite 40 rounds | R-97 hipfire spread growth |
| 4 | Is Spitfire appropriately constrained by mobility? | Stationary lane vs mobile/close play, R-201 control | It dominates both scenarios with no meaningful weakness | Review tradeoffs; **no initial buff** |
| 5 | Does the Flatline/G2 25%-ADS trial improve feel without collapsing roles? | Trial off/on, CAR control, standard reload setup | Clear benefit without outclassing SMGs or breaking mod coexistence | Adjust/revert **ADS scale**, not compensate with damage nerfs |
| 6 | Are burst/charge/shotgun mechanics functioning as intended? | Mode-specific tests, not nominal-RPM rankings | Verified mechanical mismatch or repeatable severe role failure | Identify the exact mechanic **after** diagnosis |

### Minimum isolated test design

1. Confirm the private map survey has ended/restored, matching Northstar runtime is present, and current saves/configs are backed up. No tests or deployment during a frozen queue.
2. Inspect **effective installed** weapon variables, attachments, and loadout. Verify the Alternator classname and G2 reload/ADS KeyValue coexistence. Do not treat the third-party snapshot as installed truth.
3. For each same-role pair, choose fixed equal distances and standardized standing ADS, moving ADS, moving hipfire and weapon-swap trials. Repeat each scenario at least **10 engagements** per weapon/condition and record time to first accurate hit, hit/miss counts, effective TTK (including misses), burst pauses/recoil drift and subjective handling. Ten is a pilot sample, not proof of statistical significance.
4. Use the same target health, movement script, aim input, ammunition, attachments and frame-rate for comparisons. Include both initial engagement and sustained-fire scenarios. Record rare state changes (reload, empty clip, mid-magazine spray) separately.
5. Do not mix these human test results with historical bot-control recordings. Keep bot weapon aim/AI behavior as a separate matched control; preserve human+15 bot population and aim `0.78` outside this isolated study.
6. Only after repeated, clear role failure: make **one small change to one weapon and one stat family**, retest against its original controls, and preserve a rollback. Reject changes that erase another weapon's distinct advantage.

## Status

- **Reference facts and arithmetic:** checked from the pinned 30-weapon snapshot.
- **True underperformers:** **NONE CONFIRMED** with current gameplay evidence.
- **Code changes authorized by this analysis:** documentation/verification only. Current draft ADS and mapping PRs remain separate, off by default or undeployed.
- **Next action requiring the user's installed environment:** controlled Northstar validation with current saves/survey state protected.
