# BT7274.LocalPersistence

Local-only Pilot/Titan loadout and basic progression saving for Northstar
direct-map solo games. Version 1.2.1 waits for stock player initialization
before restoring, then refreshes CLIENT and UI caches when networked loadout
fields change. LOCAL_LOADOUTS_UI reports menu-cache checks.

Cache synchronization is deliberately data-only. Do not call the stock
UpdateCachedLoadouts_Delayed helper from the background watcher: it clears
and rebuilds 3D preview models and can erase a tactical preview while it is
being equipped. Version 1.2.0's helper caused that race; 1.2.1 calls only
UpdateAllCachedPilotLoadouts/UpdateAllCachedTitanLoadouts and updates UI
selection indices. The active menu retains ownership of its preview models.
Copy this folder into the solo profile's `mods` directory. Requires Northstar
Safe IO and the existing BP_ORT solo setup. No DLL replacement is required.

`bt7274_local_loadouts` defaults to 1. It acts only for the local human when
`ns_auth_allow_insecure` is enabled. It saves whitelisted loadout fields on
edits and checks once per second, restoring on local client connection.
Saves are in `<profile>/save_data/BT7274.LocalPersistence/loadouts_<UID>.json`,
with a previous snapshot beside them. Keep the folder name unchanged so
Northstar uses the same Safe IO namespace.

Version-2 JSON stores 902 named fields, including Pilot XP/generation,
credits, weapon XP/mod flags, Titan/faction XP and Aegis XP/points. Existing
version-1 loadout files migrate without replacing their equipment. It does
not synchronize cloud data, all statistics/challenges/purchases, or match settings.
An unreadable or incompatible existing save pauses saving to preserve it.
See `%USERPROFILE%\northstar-crash-audit\Notes\LOCAL-LOADOUTS.md` for test
evidence and recovery boundaries. Do not copy the isolated test profile's
synthetic loadout JSON into an everyday profile.
