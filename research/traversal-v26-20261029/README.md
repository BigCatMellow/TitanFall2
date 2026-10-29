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
The full project checks, including four migration/preset fixtures, also passed between games.
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

## Runtime result: not promoted

Native EBB6D53136C54BCA83075B760CB6FA9C87650C1445CF2273DC91B17A86DCD1FA
completed all five smoke phases, respawn, switch-off, lobby and Eden-to-War-Games
transition with zero detected runtime-error markers. Normal remains BC2C1019...;
all ten normal save/deployment/settings guards were unchanged after the test.

Eden:8actions,0completed,7failed,1cancelled. Failures were4ApproachTimeout,
2EarlyLanding,1NoLift. All three launched failures ended from flight before a
logged second press. War Games:50actions,2completed,28failed,20cancelled;
22EarlyLanding,5ApproachTimeout,1LostEntry. Fifteen cancellations were combat or
disable, four replan and one no-navigation. Different links/actions/phase timing
make the two War Games completions versus v25's one unsuitable as a gain claim.
The lifecycle smoke passed; traversal effectiveness did not earn promotion.

A straight entry allowed a measured260units/s launch, but landed on an intermediate
surface about47units above entry before the second press. Another approach came
from the exit-facing side of the entry, requiring reversal; it timed out with
little forward velocity. These are individual diagnostic examples, not visual
confirmation. Simply preserving momentum or extending a timer is insufficient.

Next candidate needs collision-checked approach staging and explicit intermediate
surface handling, then airborne locomotion ownership across combat/target changes.
Do not blindly add more jumps or assume all type16 links have the same usable arc.
The original frozen BC2 routing study resumed after this test; normal play was
never switched to the prototype. Raw logs and DLLs remain private.
