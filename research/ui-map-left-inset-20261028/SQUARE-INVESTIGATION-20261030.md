# Square minimap investigation — 2026-10-30

Requested: a genuinely square visible minimap, not just a larger circular map.
No HUD mod installed, no profile/settings/saves changed, no game launched.

Read the installed Northstar.Client1.31.14 client/cl_minimap.gnut. It exposes
size/zoom setters and creates separate stock RUI assets for base, wedges, local
player, markers, pings and layers. No shape setter was found in that script.
A square topology alone does not establish square clipping of the visible map;
the previous topology fragment is still a research reference, not a solution.

Downloaded Team036 ClientMinimapCallbacks1.0.2 and Hugemap1.2.0 to private
integration target/minimap-reference for read-only inspection. The former
provides minimap state/callback/redraw/scale support; the latter toggles existing
minimap zoom/size on M. Neither inspected implementation changes the map shape.
No third-party package or game asset is copied into the public repository.

Primary package pages:
- https://thunderstore.io/c/northstar/p/Team036/ClientMinimapCallbacks/v/1.0.2/
- https://thunderstore.io/c/northstar/p/Team036/Hugemap/

Windows computer-use skill was read/applied; native pipe unavailable on initial
list_windows, retry, and one fresh-kernel recovery. No live visual capture was
available. Existing game-generated Kodai screenshot from2025shows a round map;
that is historical context, not current-session visual verification.

Next implementation needs a supported custom square RUI/renderer or a confirmed
shape argument in the installed assets, followed by alignment checks for all
marker layers, map transitions, player/Titan HUD, resolutions and teardown.
Do not describe a resized circular map or square topology as completion. Do not
replace the normal client script with the old community callback override just
to obtain scale controls already present in installed Northstar. Bot/gameplay
changes from the preceding turn remain intact; no HUD experiment is running.
