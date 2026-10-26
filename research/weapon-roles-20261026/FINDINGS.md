# Titanfall 2 pilot weapon role and balance review — 2026-10-26

**Decision:** do not change weapon damage or fire rate across the board. The available evidence is sufficient to map roles and isolate test priorities, but **not** to claim a weapon needs a numeric buff or nerf in James's installed game.

**Targeted follow-up:** [Which specific roles may be failing, and what evidence would justify a weapon-specific adjustment?](GAP-ASSESSMENT.md). It distinguishes reference facts, arithmetic, hypotheses and unknown gameplay outcomes.

## Evidence and authority

- **30 selectable pilot loadout weapons**, covering assault rifles, SMGs, LMGs, snipers, shotguns, grenadiers, pistols and anti-Titan equipment. The boost-only **Smart Pistol** and NPC/event-only weapon classes are explicitly outside this comparison; automated target acquisition needs a separate evaluation.
- Reference data: [BigSpice's published Titanfall 2 weapon scripts](https://github.com/BigSpice/TitanFall-2-Skin-Modding/tree/bc13e6120e37b3ccdbc0cba55e61fd978bdcbe21/Weapon_Scripts), pinned at commit `bc13e6120e37b3ccdbc0cba55e61fd978bdcbe21`, with a blob SHA per script in [reference-stats.json](reference-stats.json).
- Used `MP_BASE` damage values, rather than single-player overrides or menu `stat_damage` ratings. `fire_rate` in weapon scripts is shots/second; nominal RPM is that number multiplied by 60.
- **This is a third-party reference snapshot, not a live Northstar extraction.** Attachments, game modes, recoil curves, player/bot behavior and current installed changes can alter actual values. Do not treat this as proven active game state.
- Northstar's [weapon KeyValue reference](https://docs.northstar.tf/Modding/guides/keyvalue/weaponkeyvalues/) defines the underlying fields. We do not store or redistribute the full copyrighted game scripts.
- Repo `main` remains unchanged. Separate draft [PR #1](https://github.com/BigCatMellow/TitanFall2/pull/1) corrects actual Alternator/Volt mapping, and [PR #2](https://github.com/BigCatMellow/TitanFall2/pull/2) tests 25%-shorter Flatline/G2 ADS for **the local human only**, default OFF. Neither is merged, installed or runtime-verified here.
- Preserve the verified solo baseline (human + 15 bots, aim `0.78`, recharge/reload modifiers, saves, nav/teardown fixes). The private overnight survey state must be checked before any game or isolated-profile modification.

## Most useful numerical findings

1. **SMGs retain a structural close-range identity:** CAR, Alternator, Volt and R-97 list standing and moving hipfire base spread **0** with stock ADS in/out **0.20/0.15 seconds**. That does **not** prove zero actual dispersion: recoil and spread growth can still occur. R-97 in particular lists **0.5 spread kick per hipfire shot**, unlike the CAR's **0**.
2. **The 25% ADS experiment is aggressive:** Flatline/G2 change from stock **0.25/0.20 s** to estimated **0.1875/0.15 s**. ADS-in becomes slightly faster than those stock SMGs, and ADS-out matches them. This is a meaningful *upper-end test*, not necessarily a final balance choice.
3. **G2's ranged identity is already measurable:** 40 body damage near and 35 far means **three body hits to defeat a hypothetical 100-HP target at either band**. Its 5.5 shots/s and large **5.5** standing hipfire spread are corresponding constraints. Increasing damage toward 50 could turn that three-hit threshold into two—too large to pair casually with faster ADS.
4. **Flatline offers a different rifle tradeoff:** 30→20 near/far damage at **600 nominal RPM**, versus R-201's 25→17 at **810 RPM**. Flatline has a 30-round magazine and base standing hip spread **1**, versus R-201's 24 rounds and spread **2**. Its slower close-range theoretical body TTK is a real distinction; neither should be assumed inferior without hit-rate data.
5. **The SMGs already have differentiated rhythms:** Alternator **35/600 RPM/20 rounds**; CAR **25/846 RPM/30**; Volt **25/660 RPM/33**; R-97 **20/1080 RPM/40**. Their near-band ideal body TTKs against 100 HP cluster relatively closely (roughly 0.20–0.27 seconds), but recoil, handling, falloff and real accuracy may separate them sharply.
6. **Several headline RPM figures are misleading:** Hemlok fires three-round bursts with an additional 0.25 s burst delay; Devotion accelerates from **5 to 15 shots/s over 1.75 s**; Cold War has **0.5 s charge** and a four-shot burst; Kraber has **1.60 s rechamber**. No general DPS ranking should use their nominal RPM alone.
7. **Recoil cannot be reduced to one number.** Weapon scripts also use springs, kick growth and potentially pattern/animation behavior. Examples: CAR standing hip spread kick **0**, G2 **0.7** and ADS kick **0.075**, Spitfire hip kick **1.5**. These are useful test leads, not measured recoil amplitudes.
8. **Shotguns, projectiles and anti-Titan weapons require separate models.** EVA-8's listed 200 near damage, Mastiff's 20, Double Take's 30 and Charge Rifle's 300 are not equivalent to a single rifle bullet hit. Pellet/multi-projectile counts, blast, charge, travel time and heavy-armor values matter.

## Weapon-by-weapon role matrix

Numbers below are *unmodified published reference values*. `Near → far` denotes listed direct body damage; for shotguns, explosive/projectile and anti-Titan guns this may be a per-projectile or otherwise non-comparable component.

### AR (5)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| R-201 | 25 → 17 | 810 | 24 | 2.0 / 0 | 0.25 / 0.2 s | General-purpose automatic rifle; usable near and mid-range | Control |
| R-101 | 25 → 17 | 810 | 24 | 2.0 / 0 | 0.25 / 0.2 s | R-101 variant; compare sights/recoil feel with R-201 | Compare |
| Hemlok | 33 → 25 | 930 | 24 | 5.5 / 0 | 0.25 / 0.2 s | Burst precision at mid-range; rewards deliberate volleys | Cadence test |
| Flatline | 30 → 20 | 600 | 30 | 1.0 / 0.0 | 0.25 / 0.2 s | Heavier-hitting automatic rifle with more falloff reach | ADS test |
| G2 | 40 → 35 | 330 | 14 | 5.5 / 0.0 | 0.25 / 0.2 s | Semiauto precision rifle; retains damage at range | ADS test |

### SMG (4)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| CAR | 25 → 13 | 846 | 30 | 0.0 / 0.0 | 0.2 / 0.15 s | Mobile, consistent close-range tracking | Control |
| Alternator | 35 → 18 | 600 | 20 | 0.0 / 0.0 | 0.2 / 0.15 s | High-impact, low-magazine close-range automatic | Mapping test |
| Volt | 25 → 15 | 660 | 33 | 0 / 0.0 | 0.2 / 0.15 s | Controlled-cadence, mid-reach SMG; predictable tracking target | Control |
| R-97 | 20 → 12 | 1080 | 40 | 0.0 / 0.0 | 0.2 / 0.15 s | Fast spray/tracking SMG with small per-shot damage | Spread test |

### LMG (3)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| Spitfire | 35 → 25 | 540 | 80 | 1.5 / 0.0 | 0.3 / 0.3 s | High-capacity area control; weak snap response | Movement test |
| Devotion | 25 → 20 | 300 | 55 | 2.0 / 0.4 | 0.3 / 0.3 s | Sustained-fire ramp-up payoff | Ramp test |
| L-STAR | 25 → 18 | 720 | 35 | 1 / 1 | 0.3 / 0.3 s | Projectile-based pressure with heat management | Special test |

### Sniper (3)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| Kraber | 350 → 350 | 111 | 4 | 10 / 0.0 | 0.4 / 0.3 s | One-hit precision with severe miss penalty | Special test |
| Longbow DMR | 55 → 55 | 180 | 6 | 8 / 0.05 | 0.4 / 0.3 s | Reliable long-range two-hit precision | Range test |
| Double Take | 30 → 30 | 120 | 12 | 8 / 0 | 0.4 / 0.3 s | Multi-projectile precision and lead prediction | Special test |

### Shotgun (3)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| EVA-8 | 200 → 10 | 165 | 6 | 8 / 8 | 0.25 / 0.2 s | Fast repeatable close-quarters blast | Pellet test |
| Mastiff | 20 → 12 | 78 | 4 | 0 / 0 | 0.25 / 0.2 s | Heavy horizontal projectile volley, slower follow-up | Pellet test |
| Mozambique | 30 → 25 | 180 | 6 | 0 / 0 | 0.2 / 0.15 s | Highly mobile three-projectile close-range hybrid | Pellet test |

### Grenadier (4)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| EPG | 100 → 100 | 60 | 5 | 0 / 0.0 | 0.2 / 0.15 s | Direct-hit/reliable blast precision projectile | Projectile test |
| Softball | 10 → 10 | 120 | 6 | 0.25 / 0.35 | 0.2 / 0.15 s | Sticky explosive placement and anticipation | Projectile test |
| Cold War | 30 → 30 | 720 | 12 | 0.5 / 0.0 | 0.2 / 0.15 s | Charged four-shot explosive burst | Cadence test |
| SMR | 50 → 50 | 540 | 20 | 0.5 / 0.0 | 0.2 / 0.15 s | Sustained micro-rocket pressure with anti-Titan utility | Projectile test |

### Pistol (4)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| RE-45 | 20 → 13 | 780 | 20 | 3 / 0.0 | 0.2 / 0.15 s | Emergency fast-draw automatic sidearm | Control |
| P2016 | 30 → 20 | 480 | 12 | 2.5 / 0.0 | 0.2 / 0.15 s | Deliberate accurate quick-draw sidearm | Control |
| B3 Wingman | 40 → 40 | 156 | 6 | 1.0 / 0.0 | 0.2 / 0.15 s | High-recoil medium-impact revolver | Recoil test |
| Wingman Elite | 75 → 55 | 156 | 6 | 0 / 0 | 0.2 / 0.15 s | High-stakes precision hand cannon | Precision test |

### Anti-Titan (4)

| Weapon | Near → far damage* | Nominal RPM† | Mag. | Standing hip / ADS spread‡ | Stock ADS in/out | Intended strength | Test priority |
|---|---:|---:|---:|---:|---:|---|---|
| Charge Rifle | 300 → 300 | 60 | 0 | 3.0 / 0.35 | 0.2 / 0.15 s | High-value charged anti-Titan precision | Special test |
| Archer | 100 → 100 | 60 | 1 | 3 / 0.2 | 0.35 / 0.35 s | Lock-on anti-Titan single missile | Lock test |
| Thunderbolt | 70 → 70 | 120 | 1 | 3 / 0.2 | 0.35 / 0.35 s | Travelling energy-area anti-Titan lane damage | Projectile test |
| MGL | 20 → 20 | 360 | 6 | 0.25 / 0.35 | 0.2 / 0.15 s | Close-range magnetic grenade anti-Titan pressure | Cadence test |


\* Near/far values are not automatically actual kill damage; multi-projectile impacts, explosions, headshots, range interpolation and modifiers can change outcomes. Anti-Titan rows show the **pilot-damage** field, not armored-target damage.

† RPM is nominal `fire_rate × 60`, **not** effective burst/spin/charge/rechamber cadence.

‡ Standing spread entries are raw fields, **not measured bullet-group size**; zero base spread does not eliminate viewkick or later shot spread.
Full reference fields (falloff distances, movement/air spread, recoil spring, per-shot spread growth, charge/burst/rechamber, deploy/holster) are in `reference-stats.json`.

## A limited 100-HP body-shot comparison

This is deliberately a *static illustration*, not an actual pilot time-to-kill simulation. It assumes every body shot lands, no armor/headshots/amp/lag/attachments, and that the first hit occurs instantly at the nominal firing state. It excludes ADS, movement and projectile travel. Burst weapons are not treated as continuously firing.

| Weapon | Near hits | Far hits | Near nominal shots-only TTK | Interpretation |
|---|---:|---:|---:|---|
| R-201 | 4 | 6 | 0.222 s | Use as rifle control; no stat change |
| Hemlok | 4 | 4 | Not comparable (burst) | 3-shot burst/0.25 s delay; no RPM-only buff |
| Flatline | 4 | 5 | 0.300 s | Assess 25% ADS trial; retain meaningful hip/recoil tradeoffs |
| G2 | 3 | 3 | 0.364 s | Assess trial against CAR/SMGs; no damage buff |
| CAR | 4 | 8 | 0.213 s | SMG handling control; preserve fast hipfire |
| Alternator | 3 | 6 | 0.200 s | 35 near / 600 RPM / 20 rounds; verify classname fix PR #1 |
| Volt | 4 | 7 | 0.273 s | Volt, not Alternator; preserve medium-range distinction |
| R-97 | 5 | 9 | 0.222 s | Hip base 0 but firing spread kick; confirm sustained bloom |
| Spitfire | 3 | 4 | 0.222 s | Check suppression and strafe weakness before any tuning |
| RE-45 | 5 | 8 | 0.308 s | High rate offsets low bullet damage |
| P2016 | 4 | 5 | 0.375 s | Higher impact, slower cadence than RE-45 |
| B3 Wingman | 3 | 3 | 0.769 s | Substantial hip kick; emphasize skillful precision |
| Wingman Elite | 2 | 2 | 0.385 s | Two body hits near/far (100 HP), slower cadence |


**Important:** one additional shot can matter more than a small percentage damage change. Do not change base damage before checking its effect on shot-count thresholds at *near, far, and falloff transition distances*.

## How to define “good at its job”

- **SMGs:** fastest reliable hipfire and tracking in motion, weaker across long sightlines. Their identity must survive any rifle ADS buff.
- **Assault rifles:** more stable across middle distances, meaningful tradeoffs in hipfire, cadence, magazine and precision. R-201 is the baseline all-round control.
- **G2/Hemlok/DMR precision weapons:** reward aimed hits and disciplined cadence, lose convenience in panic close-range encounters.
- **LMGs:** strong sustained pressure and large magazines, a cost in initial handling/movement or warm-up.
- **Snipers:** reach and precision, significant penalty for a miss or rushed engagement.
- **Shotguns:** win positioning/close range, clearly lose consistency with range and missed pellet coverage.
- **Grenadiers:** reward lead, arcs, charge, impact timing, and area denial rather than ordinary hitscan precision.
- **Sidearms:** provide reliable, fast switching and tactical recovery without eclipsing primaries.
- **Anti-Titan:** be valuable against armored targets with clear targeting/charge/reload tradeoffs; pilot DPS is secondary.

## Recommendations and next evidence gate

**Hold for now:** no damage/RPM changes, no uniform recoil reduction, no global AI aim change, no default-on weapon handling changes.

1. **Validate installed versus reference values.** For R-201, CAR, Alternator, Volt, Flatline, G2 and Spitfire, inspect installed effective KeyValues/attachments and confirm `MP_BASE` plus local modifiers. Verify actual Alternator classname and PR #1 mapping independently.
2. **Isolated ADS A/B.** For Flatline and G2 compare stock and draft-PR-#2 0.75 transition scaling across hip-to-ADS time, first accurate hit, target switch, ADS-out, and G2 reload+Speedloader coexistence. Include CAR and Volt controls. Test normal human and bot-held guns separately; the mod should remain human-only.
3. **Recoil/spread capture.** At short/mid/long standardized distances capture multiple no-input and tracking groups: stationary hipfire, moving hipfire, grounded ADS, moving ADS. Repeat at least three times per mode with fixed attachments, frame-rate and target. Track first-shot offset, repeatability, per-shot bloom, and hit ratio rather than relying on one viewkick coefficient.
4. **Role dominance check.** If the Flatline/G2 are now effectively as good as an SMG in close/mobile work *and* retain superior range, reduce the **ADS trial** first (e.g. 0.80 scale) rather than nerfing damage/RPM to compensate for an untested handling buff.
5. **Only then propose one-variable tuning.** If a gun is reliably weak in its intended niche across repetitions, change a single recoil, spread, or handling field with a documented predicted effect, control gun and rollback. Damage/RPM comes last after shot-count and cadence analysis.
6. **Preserve the survey baseline.** Do not conflate historical R-201-dominant bot logs with a randomized comparison of all 30 weapon classes. No live weapon effectiveness, win-rate, handling outcome or new deployment has been measured here.

## Verification status

- Reference coverage: **30/30** explicitly inventoried classnames and per-file source SHA.
- New analysis is **source-only**; no game launched, no private saves/profile edited, no native/worker changes, no merge.
- Static data/tests are in this proposal; full Windows Northstar and A/B validation remain pending.
