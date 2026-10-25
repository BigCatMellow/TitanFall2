# James.LocalPersistence

Local-only Pilot/Titan loadout saving for Northstar direct-map solo games.
Copy this folder into the solo profile's `mods` directory. Requires Northstar
Safe IO and the existing BP_ORT solo setup. No DLL replacement is required.

`james_local_loadouts` defaults to 1. It acts only for the local human when
`ns_auth_allow_insecure` is enabled. It saves whitelisted loadout fields on
edits and checks once per second, restoring on local client connection.
Saves are in `<profile>/save_data/James.LocalPersistence/loadouts_<UID>.json`,
with a previous snapshot beside them. Keep the folder name unchanged so
Northstar uses the same Safe IO namespace.

This does not synchronize cloud loadouts, XP/statistics, or match settings.
An unreadable or incompatible existing save pauses saving to preserve it.
See `C:\Users\james\northstar-crash-audit\Notes\LOCAL-LOADOUTS.md` for test
evidence and recovery boundaries. Do not copy the isolated test profile's
synthetic loadout JSON into an everyday profile.
