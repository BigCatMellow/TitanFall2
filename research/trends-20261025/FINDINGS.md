# Good and bad trends in the accumulated v16 data

Offline analysis of16 recordings across10 maps:10 completed controlled trials,
one interrupted controlled trial and5 played rounds. No game launch, survey
resume, deployment or weapon/ability tuning occurred. Played/unattended and
partial cohorts remain separate. [Summary](SUMMARY.md), [rounds](rounds.json),
[aggregates](map-cohorts.json), [reproducible builder](../../tools/Build-TrendSummary.ps1).

## Positive patterns

- Controlled sustained navigation low-progress fractions are low on Crash
  Site0.40%, Angel City0.72% and Drydock0.98%. Latest played Exoplanet is1.03%.
  These are useful comparison cases for a localized fix.
- Three Meadow recordings (one unattended,two played) have zero samples under
  the stricter detector. This does not rule out short stalls; a small arena
  is not equivalent to a full-size map.
- The latest played log completed Eden→lobby→Exoplanet→lobby and shut down
  cleanly. Loadout logs repeatedly saved/restored902 named fields. These are
  positive stability/persistence observations, not a crash guarantee.
- Latest played Eden was1.23% sustained navigation low progress; older played
  Eden was9.72%, with the same v16 behavior. Encounter routes strongly affect
  whether a match exposes a bad spot. No new fix was deployed between them.

## Targeted problems

**Eden:** two fresh controlled recordings aggregate7.21% sustained low-progress
samples. Older played Eden repeatedly hits cells around(4096,-256,128), affecting
six bots. The better recent round means an average does not describe every
match. Focus on the specific route/collision sequence before global navigation
or jumping changes. It is a reproducible hotspot, not a universal bad-map rate.

**Complex:** controlled2.45% remains higher after stricter filtering. Earlier
reports place52 of109 original flagged samples in one cell, all slot11. Reproduce
that actor/location rather than assuming every route is broken.

**Overhead targets:** targets over5000units above appear in4.55% of latest
Eden visible-engage pilot snapshots,5.87% on played Exoplanet,9.98% in older
played Eden. Source candidate/vision checks use XY distance and include live
pet Titans. A descending example is consistent with incoming Titans, but
exact transit state is absent. Investigate eligibility in BOTH visible choice
and pursuit fallback, preserving reachable nearby threats. Selection does not
prove firing or wasted shots; cached ammo is not reliable firing evidence.

**Target churn:** Titan-context quick reversals were about59% on Colony/Complex,
but Drydock is24.99% for Titans and31% for pilots. Some switches are appropriate
visibility/threat reactions. Exact actor/current-shootability diagnostics are
needed before a bounded continuity trial; blanket retention risks delayed reactions.

**Combat steps:** existing code stops a range-hold/backstep if its chosen trace
is blocked. It could test the opposite side with the same wall/ground checks
before staying still. This needs separate wall/ledge runtime validation and
safe stopping when neither side is clear.

## Weapons and skills: evidence gaps

Bot combat in the main trials and latest played maps is still R-201. There is
no representative weapon-class dataset. Human shots/hits, weapon damage and
tactical outcomes are not comprehensively logged. Exact K/D, time-to-kill and
ability balance cannot reliably come from two-second positions/HP alone.

Keep the validated human50% tactical recharge and10% reload adjustment on
G2/Alternator/R-201/CAR as the reference. Aim0.78 and8v8 remain selected. A
later matrix should cover SMG/rifle/shotgun/precision/projectile/heat weapons.
Current evidence supports decision/route investigations, not blanket numerical buffs.

## Measurement changes and limits

The builder accepts v16 only, removes lobbies and trims played rounds from
playing callback to match completion using preceding two-second frames
(approximate boundaries). It checks the same live pilot over10–13seconds and
flags below50 XY units net displacement. The strict variant additionally
requires every sampled state in that window to be navigation/recovery/boarding.
This avoids counting a long deliberate firing hold followed by a brief pursuit
as10seconds of failed navigation. Life/type boundaries reset the window.

These stricter values are not interchangeable with old percentages; original
reports are retained. Endpoint displacement can flag a loop without proving
immobility or revealing collision scenery. Overlapping samples are not
independent incidents. No randomized A/B improvement claim follows.
Fixtures cover sustained navigation, intervening engagement and a life reset.

Next experiments, once authorized: validate diagnostics; investigate incoming
Titan eligibility; reproduce Eden/Complex obstruction; test a safe opposite-side
step; then collect representative weapon/ability outcomes. The17 unfinished map
trials stay paused, and current human saves must be preserved.
