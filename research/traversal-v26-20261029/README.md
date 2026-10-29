# Momentum-aware traversal experiment

This is a default-off native prototype on top of v25, not the normal deployment.
The current stable baseline stays on the v23 Eden repair.

## Question and implementation

The v25 smoke produced five Eden early landings without a completed action; on
War Games there was one completion, 29 failures and 13 cancellations. The leading
hypothesis is lost launch momentum, not a proven geometry diagnosis.

The revised action arms up to 160 units before a known type16 entry with its
matching type255 exit. It moves toward the entry while looking toward the exit,
then keeps moving toward the exit after takeoff. Long segments require measured
forward velocity of at least 180 units/s (100 for segments <=192 units). Sideways
or backward speed cannot satisfy that check. It never writes velocity or changes
physics. The same two released jump pulses, bounded landing predicate, retry
cooldown and local failed-type detour remain. Approach time is bounded to1.2s;
total action ownership to3.5s. Unsupported geometry and cooldowns cannot consume
an early corner. Visible combat/replans still cancel the prototype; independent
airborne movement ownership is a separate follow-up, not implemented here.

## Validation

105 Rust policy checks across19 suites pass, including momentum/run-up, wrong
heading, invalid velocity, grounded launch, two released presses and expiry.
Pinned locked offline Windows release-debug build passes. Dependency lock bytes
remain E4F8434813F688AF4FB5184EAEF4876A7F72F79C1D6B2A4DAB69C7BF2B89AE41.
Full PowerShell migration fixtures are not run while game processes are active.
Runtime checks and native hash will be recorded separately; source tests do not
establish traversal success or a difficulty improvement.

## Next architectural work, ordered by evidence

1. Test approach momentum on the same directed Eden link and full War Games
   lifecycle. Decline rollout if failures remain or cancellations dominate.
2. Give a committed airborne action brief locomotion ownership while preserving
   combat aim, with explicit death/hull/disable/map cancellation and deferred
   replans. Test that jump release survives target changes before enabling it.
3. Use owned projectile measurements to distinguish grenade launch/exposure
   hypotheses. Current self/enemy death counts do not identify the cause; do not
   change fuse, damage or grant immunity as a workaround.
4. Extend typed traversal only after confirming each mesh type's meaning and
   measuring launch/landing outcomes. Existing meshes are a route source, not a
   complete controller for grapple, wall-running or all vertical movement.
5. Add bounded team lanes/spacing and resource-aware decisions after locomotion
   works. Compare matched map cohorts; preserve fair aim and the firing warm-up.

This separates candidate logic, frozen study cohorts and stable play. A new
feature must improve the corresponding measured failure and survive lifecycle
checks before promotion. Weapon power is not a substitute for better movement.
