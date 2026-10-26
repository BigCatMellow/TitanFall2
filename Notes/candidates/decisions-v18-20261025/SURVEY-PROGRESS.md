# Survey progress — 2026-10-25 20:49 EDT

Two of 22 maps completed with the frozen v18 native/bridge build:

| Map | IMC | Militia | Finish |
|---|---:|---:|---|
| Forwardbase Kodai |129|163|15-minute limit|
| Boomtown (mp_grave) |169|161|15-minute limit|

No runtime error was detected in those two matches; movement/combat reports
were generated. These bot-only results do not establish human difficulty or
improved balance. Map names follow the [Northstar file-name reference](https://docs.northstar.tf/Wiki/hosting-a-server-with-northstar/server-settings/file-names/).

Homestead failed twice before the controlled match began: an empty weapon name
in the intro HUD, then an empty weapon name in the cached loadout model path.
The original failed attempt and unchanged-build retry remain recorded; neither
is a completed bot trial. Exact causality is unresolved. The first runner's
immediate cleanup missed a briefly lingering exited process; its configuration
was restored afterward, without restoring any saved data. Shutdown now waits
for the owned process to disappear before checking restoration.

A new subcohort disables named human loadout restoration for the inactive
survey observer only (`james_local_loadouts 0`). It passed Homestead startup with
16 bots, 8v8, observer dead, and advancing scores. This supports isolating the
observer/persistence startup path, but does not prove a fix to normal play.
Normal profile files/settings remain unchanged in this follow-up; all three
normal save files still match the current deployment backup.

Current private batch: decisions-v18-observer-defaults-20261025-204736.
20 maps are queued, including the running Homestead attempt. Prior completed
maps are skipped by validated ResumeBatch support; frozen native, bridge and
core hashes must match. Observer configuration is recorded in plan.json and
must remain distinct when comparing startup/performance behavior.

Check the live current-v18-session.json/status.json before acting. To pause,
create stop-after-current.txt in the CURRENT batch. The older two stopped
batch folders remain intact. Runtime binaries/raw logs/personal saves stay local.
