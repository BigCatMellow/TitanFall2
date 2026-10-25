# Skill and steering adjustment (v11)

The player reported that v10 bots were too easy and still sometimes spun or
jumped while following paths. The solo preset keeps `bot_aim_penalty_speed -1`
and adds `bot_aim_error_scale 0.8`, reducing the existing randomized angular
error against pilot targets by 20%. This is not a measured 20% increase in
hit rate. The multiplier defaults to 1, is bounded to 0.25–2, and invalid
nonfinite values fall back to 1. Titan-target aiming retains its existing
error behavior.

The old combat yaw clamp compared raw -180/+180 angles; turning from +179 to
-179 could rotate the long way around. Steering now wraps the angular
difference and takes the shortest turn. Navigation turns are bounded at 540
degrees per simulated second, and duplicate/coincident path nodes no longer
create an arbitrary turn toward zero degrees. All nearby nodes are consumed
in one update. Recovery jumps are requested no more than once every 1.2
seconds, while the normal raised-waypoint jump timing stays unchanged.

Three new regression tests cover the angle seam, bounded turns, and invalid
settings. The eight prior jump, movement-watchdog, and native output-buffer
tests also pass. These changes address specific steering/recovery defects;
the legacy navigation mesh can still miss pilot rooftops and airborne goals.

DLLs before this change and the solo config are backed up in
`C:\Users\james\northstar-crash-audit\skill-steering-v11`.

The bot/client iteration and native server binding have 32 client slots.
That makes 32 total participants (one human plus 31 bots) the ceiling this
build is designed around. It has not yet been stress-tested at that count.
The existing game playlist advertises 16 slots. Larger counts require both
the playlist/server cap and the bot manager target to be raised; changing
only the target is insufficient. Match-size selection is pending.

Installed DLL SHA256:
`DBE7301BFCAEF61E16165B3456D9F8EF851807DF2F64EDD768E2A9928EC63C48`.
The fresh visible solo launch on Relic (`nslog2026-10-24 13-16-25.txt`)
spawned seven bots. By 13:18:30, 37 movement records confirmed the 0.80
multiplier, seven records showed damage/death, and no script errors, native
access violations, or panics were recorded. This short live check confirms
the preset is active and bots move/fight; it does not prove all navigation
stalls are resolved or measure the perceived difficulty increase.
