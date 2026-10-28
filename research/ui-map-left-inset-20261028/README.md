# Larger left minimap inset

**Status:** research candidate. No game profile, HUD setting, or save was changed. The code fragment is not a standalone Northstar mod and has not been runtime-tested.

## Target

Keep a larger map visible during a match in a left-side inset. The current corner minimap is too small and poorly placed for useful route awareness.

## What the APIs support

- Team036's client minimap callback package exposes zoom and size setters, redraw helpers, and access to the minimap state. It does not document an on-screen position setter. A scale-only change therefore cannot guarantee the requested placement.
- The mirrored stock `cl_minimap.gnut` creates the map base, threat wedges, player marker, indicator, entity markers, pings, and layers with `CreateCockpitRui`. That makes the existing minimap a set of RUI objects, rather than a normal `.menu` HUD element.
- Northstar's RUI API can draw on a screen-space HUD topology. `RuiTopology_CreatePlane` takes pixel coordinates, and `RuiCreate` can put RUI assets on that topology. This gives us a plausible way to move the entire existing minimap stack together while preserving the stock tracking and icon setup.
- `Hud_SetPos` moves a declared HUD element. Based on the stock minimap script's direct RUI creation, it does not appear to be a direct handle for relocating this map.
- Team036's HugeMap package is a client-side map opened with **M** and supports custom zoom/scale. It is a useful fallback for a deliberate map check, but it does not meet the persistent left-inset target.

## Candidate code

[`minimap_inset_topology.nut`](minimap_inset_topology.nut) contains the topology helper. It must be integrated into the local Northstar client minimap script; by itself it draws nothing.

The integration needs to:

1. Add the topology field to the minimap script's existing state.
2. Route every minimap `CreateCockpitRui` call through the helper: map base, wedges, local-player marker, indicator, entity markers, pings, and layers. Keeping all of these on one topology is necessary for marker alignment.
3. Use the HUD draw group for those RUIs.
4. Destroy the custom topology at map teardown and recreate it after a map or resolution change. Northstar warns that topology slots are limited.
5. Start with the provided inset geometry and native minimap size scale, then tune after seeing it in-game. RUI asset layout, clipping, and the apparent map scale on the installed 1.31.14 build still need visual validation.

The stock script and RUI assets are not copied into this repository. Use the installed build's local source when preparing an isolated override, and retain a local backup for rollback.

## Isolated validation plan

- Prepare a separate client-mod/profile candidate; do not edit the normal HUD or save data.
- Capture a same-map baseline and candidate screenshot at the same display resolution.
- Confirm the map image, north/heading, own-player marker, friend/enemy/bot markers, tactical reveals, firing wedges, pings, and edge clipping all remain aligned.
- Check that the map does not obscure weapon/ammo, objective, or kill-feed information.
- Repeat after a map transition and at the user's normal resolution. Confirm no duplicate RUIs, stale markers, topology exhaustion, script errors, or unexpected map persistence.
- If any check fails, disable the isolated candidate and restore the local stock script.

No game process or Windows runtime was available in this workspace, so these checks remain outstanding.

## References

- [Northstar RUI API](https://docs.northstar.tf/Modding/reference/respawn/rui/)
- [Northstar topology API and screen-space example](https://docs.northstar.tf/Modding/reference/respawn/topology/)
- [Northstar HUD script API](https://docs.northstar.tf/Modding/reference/respawn/hud_script/)
- [Team036 ClientMinimapCallbacks 1.0.2](https://thunderstore.io/c/northstar/p/Team036/ClientMinimapCallbacks/v/1.0.2/)
- [Team036 HugeMap](https://thunderstore.io/c/northstar/p/Team036/Hugemap/)
- [Community mirror of the stock client minimap script](https://github.com/Syampuuh/Titanfall2/blob/master/scripts/vscripts/client/cl_minimap.gnut)

The community mirror is a research reference, not the installed Northstar 1.31.14 source of truth. The package implementations and all visual behavior still need to be checked against the local build.
