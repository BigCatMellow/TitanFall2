# Owned frag exposure screen

Seven frozen v24 bot-only rounds, five maps,542 observed projectiles. This is a
separate read-only review, not a native behavior change or a human-play cohort.

88 self-kill callbacks matched observed projectiles;86 came from projectiles
first observed moving above200units/s, two from the <=200bucket. Therefore the
specific hypothesis that most self-kills arise from nearly stationary projectiles
at first observation is not supported by this screen. Speed does not classify a
throw/drop/bounce; the sampler can first see a projectile after contact.

Every matched self-kill had a preceding owner-distance sample within0.6s. In the
(200,800] speed group, map/variant medians of last sampled owner distance range
from97 to140units, and first-observed-to-self-kill medians from2.766 to2.816s.
Sample lags have medians of0.266 to0.316s. These are seven group medians, not a
pooled median or positions at detonation. Multiple kills may share a projectile.

The next stronger experiment is projectile-relative escape after release,
validated against existing nav/hull fits. It must distinguish intent from actual
projectile position, defer unsafe tactical throws during an active crossing, and
preserve combat aiming. Existing forward braking is relative to command view,
not a guarantee the owner moves away from the grenade. Do not infer whether a
bot chased, stood, bounced a frag back, or changed floors from scalar distances.

Before a runtime escape controller, add a separate default-off probe for actual
projectile position/velocity, owner position/velocity, alive/life boundaries and
throw/release timing. Keep the current v24 measurement source frozen. Reproduce
an unsafe case and test reachable escape alternatives, then compare matched map
rounds with self-kills per observed projectile and enemy outcomes retained.
No fuse/damage/aim change or normal deployment is justified by this association.

Review-FragExposure.mjs rejects incomplete/error cohorts and duplicate spawns,
keeps unmatched kills separate, selects only preceding fresh samples and exports
no handles. Two fixtures verify temporal boundaries, overlapping outcomes,
missing/stale samples, invalid cohorts and identifier privacy. Raw logs remain
private. Individual JSON files preserve each map/variant and source-log hash.
