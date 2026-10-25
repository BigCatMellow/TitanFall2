# v15 bounded physical recovery

Starts from the verified v12 working source. Target selection, path queries,
waypoint processing, aim and coordination retain the v12 implementation.
The v14 route-memory/cache/retreat changes were rejected and removed from
compiled source after isolated tests.

`bot_escape_recovery` defaults to 0. With 1, legacy mode-6 Human-hull bots
retain normal first-stall avoidance. A second recovery within 12 seconds
and 192 horizontal units permits a 1.2-second diagonal backstep, without
jumping, instead of the original forward/jump avoidance. Adjacent bot slots
and subsequent attempts alternate sides, avoiding synchronized motion.
After that window the normal algorithm resumes. Death, hull changes and
map teardown clear this per-bot state. No route or enemy blacklist exists.

BOT_ESCAPE logs the origin, time, slot and side of each escalated recovery.
The existing observer still measures movement, combat and map population.
Three new standalone tests cover the short window, ordinary first stalls,
expiry/location resets and distinct sides. Full suite: 20 tests.
Deployment results and hashes belong in the project Notes directory.
