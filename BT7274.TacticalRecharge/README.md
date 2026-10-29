# BT7274.TacticalRecharge

## Candidate v1.1.0

This branch proposes a targeted recharge profile for an isolated solo trial:

- Grapple, Cloak, Stim, Holo Pilot, Phase Shift, and A-Wall keep half their usual recharge time for the local human.
- Pulse Blade uses its native refill rate and refill-start delay. Power Cell remains active.
- Bots, Titans, ordnance, ability effects, range, charge count, duration, and cost are unchanged.

The current main-branch v1.0.0 modifier accelerates all seven tacticals. This v1.1.0 source candidate has not been installed or runtime-tested. Keep it in the isolated `map-cycle-test-profile` until the A/B protocol and runtime checks in [the cooldown audit](../research/skill-cooldowns-20261028/FINDINGS.md) pass.

The mod multiplies native refill rates by 2 and refill-start delays by 0.5 for the six accelerated tacticals. Pulse Blade's neutral `*1.0` modifiers preserve the game's normal refill behavior while the separate Power Cell modifier composes. The rate fields are not absolute cooldown seconds; the time to readiness depends on the weapon's charge cost and resource pool.

Grapple uses a named player ClassMod in `scripts/players/mp/pilot_mp.set`. The other tacticals use named weapon Mods. Existing modifier arrays are preserved; repeated respawns/loadout changes do not stack copies. Activation runs one frame after respawn/loadout application. The profile check restricts this mod to the local human in an insecure solo session.

## Install and rollback

Use the isolated test profile only for this candidate. Back up its active mod files and current test configuration first. Do not copy old saved loadouts or saves into the normal profile.

To disable: set `bt7274_tactical_recharge 0` in the server console, then respawn or reselect the loadout. For persistent disable, add that setting to the test profile's `autoexec_ns_server.cfg`. Removing this directory with the game closed restores stock recharge for all seven tacticals.

See [the cooldown audit](../research/skill-cooldowns-20261028/FINDINGS.md) for the matched test plan and evidence limits.
