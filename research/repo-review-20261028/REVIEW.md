# Recent branch review — 2026-10-28

Reviewed remote tips without merging, building, installing or launching a game:

| Branch | Tip | Recommendation |
|---|---|---|
| research/navmesh-corner-height-guard-20261028 | cab15b8 | Highest priority for isolated bot trials, after measurement/tests |
| research/skill-cooldowns-20261028 | 63d04a6 | Good narrow human Pulse trial; keep separate from bot tests |
| research/ui-map-left-inset-20261028 | cd4d202 | Useful direction; finish client integration before testing |

All three branch merge-bases with this checkout are1b223ee. They do not include
our later v21 experiments/results. Integrate individual changes carefully;
replacing whole files could discard subsequent source or handoff work.

## Navigation: strongest match to the bot problem

The branch correctly identifies XY-only corner consumption in cmds_utils.rs.
Its default-off bot_corner_height_guard preserves the45unit XY threshold and
requires absolute height error <=36units. A separate once-per-second log gate
and per-life reset are good choices. Aim, damage, mesh data and jump policy stay
unchanged. The proposal is plausibly useful for vertically separated floors;
that is not yet evidence that recorded stalls came from this condition.

Before a trial:
- Add tests for inclusive45/36boundaries, both height signs, invalid floats,
  and preservation of switch-off behavior. Existing route_guard tests do not
  exercise the new corner_reached helper; no test file was added by the branch.
- Extend the analyzer: current parseDiag ignores BOT_CORNER_HOLD. Measure held
  corner duration and subsequent progress/timeout, not just log frequency.
- Separate pilot/Titan and ordinary/traversal corners. A single36unit absolute
  rule applies to both upward and downward corners and both hulls. It can retain
  a drop/link corner the existing movement controller does not know how to
  complete. Existing no-progress/5second timeout recovery bounds the attempt,
  but could still produce repeated replan loops rather than better movement.
- Use current release-debug/locked/offline build instructions from the latest
  safety notes; the branch's distribution-profile instructions predate the
  successful current build route.

Run matched Eden/WarGames problem-map pairs and Complex/Meadow control pairs,
with one switch changed and the same population/preset. Gate on sustained
progress, holds leading to success, route timeouts, errors and lifecycle safety.
Do not combine this with the rejected v21 grenade experiment.

## Pulse Blade: focused human balance change

Version1.1.0 neutralizes only Pulse refill rate/start-delay multipliers (*1.0),
preserving six other half-recharge tacticals and Power Cell composition. Its
per-tactical profile log corrects the misleading universal scale=0.50 message.
The audit correctly separates ammo/sec from cooldown seconds and bot requests
from confirmed casts. This changes human radar availability, not bot skill.

Keep it an optional trial pending matched throw-to-ready/scan-uptime measurements,
Power Cell on/off, other-six controls, bot exclusion, non-stacking and lifecycle/
disable checks. Migrate versioned enabledmods explicitly. It deliberately changes
one part of the existing seven-tactical50%recharge preference; no automatic
normal-profile rollout is warranted by a source review.

## Minimap: useful prototype with incomplete integration

The square inset geometry is sensible as a starting point (270px at1920x1080),
but that describes the topology viewport, not verified visible-map dimensions.
The fragment is honestly labeled non-standalone and untested.

Inspection of the installed local cl_minimap.gnut confirms a further integration
requirement: Minimap_EnableDraw resets the main and auxiliary RUIs to
RUI_DRAW_COCKPIT (lines279–286), and entity marker creation sets that group again
at line382. Updating creation calls alone would miss these later resets. Preserve
hide/show behavior while consistently selecting the inset draw group.

The fragment does not implement its proposed teardown/resolution handling. Track
and destroy owned RUIs before their topology; destroy/recreate or update for
resolution/map changes. Northstar documents limited topology slots and states
that destroying a topology does not destroy its RUIs:
https://docs.northstar.tf/Modding/reference/respawn/topology/

Integrate privately against installed source, retain marker/tracker setup,
confirm actual asset scaling/clipping visually, and keep game assets out of Git.

## Collection status at review

The validated v20 continuation finished13/13remaining rounds at08:39 onOctober28.
Coverage now reports22completed,0failed,0remaining in this Full v20 cohort.
This is collection completion, not a fresh analysis or evidence that any of
these three branches improved play. All remain uninstalled by this review.
