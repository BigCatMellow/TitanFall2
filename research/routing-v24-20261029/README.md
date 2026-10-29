# Routing study and deeper controller work — October 29

The original eight-hour window did not produce an overnight matrix: only the
Relic/War Games routing smoke completed before work paused. A renewed two-hour
window ends at08:03EDT on October29. No claim of eight hours of collected data.

Latest played v23 Full session: Relic16/6 pilot kills/deaths with3.09% overlapping
low-progress pilot samples, then Meadow23/2 and22/3 with0%. Frag self-kills91 versus
53enemy pilot kills. These are callback-derived pilot counts, not scoreboards.
New data does not justify a global damage/RPM/aim buff; ordinary human play,
small arenas and bot-only observer rounds remain separate cohorts.

The v24 study freezes the already-built v23 nativeBC2C1019..., core1.31.14 and
installed bridge1.0. Variant0 keeps the normal Eden-only repair; variant1 enables
the existing global pending-waypoint and local failed-type16 detour trials.
The global continuity trial can affect Titan routes too; pilot stall rates
alone are insufficient for a broader deployment. Aim0.78, firing warm-up,
weapon power and human modifiers remain fixed. No automatic normal deployment.

Read-only BT7274.BotMeasurements1.0 records attack callbacks/shot parameters and
sampled magazine decreases separately for the eight roster primaries. They are
not yet a validated shot/accuracy denominator. Refill and boundary windows can
hide expenditure. Owned frag entities, kill callbacks and projectile matching
provide stronger outcome denominators; missed/pre-window/invalid-owner or
invalid-inflictor cases remain unmatched. Near-end projectiles remain censored.

Study plan:50-point rounds, two reversed-order pairs on Relic,War Games,Complex
and Canal, with other installed full-size maps interleaved for coverage as time
allows. The supervisor checks native/core/bridge/measurement hashes, population,
actual variant flags and normal-profile hashes. It stops candidate variants at
a coarse matched regression cutoff, retains failures, respects a deadline and
stop-after-current file, and restores the isolated baseline without reverting
any saves. The cutoff is operational, not statistical significance or promotion.

The renewed request also authorizes a separate, more ambitious controller lane:
explicit bounded traversal actions, remembered crossing failures and eventually
projectile-relative grenade escape. Prototype source/builds must stay separate
from this frozen study and normal play until they pass isolated runtime checks.
Raw logs, personal saves, reference/game assets and binaries stay private.
