# Findings — completed v18 map survey

All22installed maps with bot navigation data now have a completed controlled
round: three configured200-point/15-minute matches, then19at75points per team.
The separate Pillars arena (mp_coliseum_column) lacks navigation data and remains
explicitly excluded. Every retained round began with16bots8v8 and an inactive
human observer; the actual core version, engine goal and harness goal were
checked from its log. No script/native error was detected in the22completed
round logs. This is successful coverage, not a guarantee of crash-free play.

The overnight job itself stopped early: its worker raced the game's own quit,
then tried to stop a PID that no longer existed.19matches were in its aggregate;
Traffic had also completed75–71 but its host failed before saving the result
metadata. Traffic was recovered from matching BEGIN/RESULT/DONE markers with
no detected runtime error; original failed status/stderr remain intact. UMA
(75–67) and Coliseum (9–75) were completed on October26. The exact cleanup race
now has a regression fixture, completed results are saved before shutdown, and
cleanup failures can no longer prevent the final status write.

## What the shorter matches provided

All19short matches reached75. Median playing time was267.4s (4m27s), ranging
from108.3s in Coliseum to718.2s in War Games. Restricting to the12regular
multiplayer maps with the75goal, median time was332.85s (5m33s). Tiny arenas
remain separate; they should not set expectations for large-map tempo.
This excludes startup/report time. Shorter runs capture less late Titan play
and rare failure opportunities; they are broad first-pass coverage.

## Next route investigations

The same phase-trimmed continuous-navigation detector used in the v16 review
was applied to the new data. The independent PowerShell reference matched the
new analyzer's pilot/sample counts exactly on all three maps below.

| Map | Low-progress pilot samples | Fraction of live pilot samples | Main evidence |
|---|---:|---:|---|
| War Games |330/4705|7.01%|84samples in cell1664,-256,128 across6slots; other shared cells also recur|
| Eden |113/2273|4.97%|37samples in cell4096,-256,128 across5slots; adjacent cell also shared|
| Drydock |50/1242|4.03%|Several smaller shared clusters; less concentrated evidence|

War Games and Eden are the strongest follow-ups. Eden's4096,-256,128cell is
also prominent in earlier v16 controls. The location recurring across builds
supports inspecting its route/obstacle context; the changed percentage does
not establish a v18 improvement or regression. Goals, duration, observer setup
and round variation differ. Do not apply a global aim/damage increase to address
these observations. Drydock warrants another focused round before tuning.

These are overlapping sampled windows, not330separate incidents or measured
player frustration. Low progress means under50XYunits net displacement across
10–13seconds with the same sampled live pilot, no gap over2.1seconds, and all
sampled states in navigation/recovery/boarding. Combat holds/deaths/gaps break
the window. Vertical movement or legitimate boarding can still resemble low
XYprogress; walls, exact route intent and visual collision remain unobserved.

Across the completed set, the analyzer found no visible pilot-engagement
snapshot selecting a target more than5000Zunits overhead. That supports further
checking the intended targeting behavior, but is not a count of incoming
Titans, shots wasted or successful ability casts. Default bot weapons/suits
remain unchanged; this is not a weapon/ability balance experiment.

## Reproduction and protection

Run tools/Review-SurveyCoverage.mjs with --batch pointing at the final private
supervisor and --out pointing at a report folder. --archive-evidence emits only
an exact whitelist of authored bot/survey diagnostics. General logs, names,
authentication data and personal saved state stay private. Evidence manifest
hashes and source-log hashes allow future verification; no binaries/assets are
published. Four analyzer fixtures, three reference comparisons, eight cleanup
fixtures and six planning fixtures passed.

All3current normal save files remained hash-unchanged during the final trials.
Idle test configuration/enabledmods hashes matched their backups, no game process
remained, and the temporary awake request was released. Native/core/readiness
builds and human gameplay modifiers were not changed during this follow-up.
