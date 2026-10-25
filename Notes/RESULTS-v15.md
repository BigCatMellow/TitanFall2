# v15 physical escape recovery — 2026-10-24

DLL SHA256:
`2A68A1CE0C0AB6294DE62C7E2742BE064C7ED086111C8251F1822FCCD22FA66C`.
Source archive: `source-snapshots\v15-escape-20261024.zip`, SHA256
`4166FEAEFC8C967ADFF4D46372355BE105E017F66EF795040D3F52E859A2BBAA`.
The tracked-change patch is beside the archive; the archive includes the
untracked module, tests, and local loadout add-on.

## Scope and verification

The broader v14 target-memory/cache changes were rejected after worse Eden
results. They were never installed in everyday solo. See RESULTS-v14.md.
v15 starts from the verified working v12 source. Native navigation,
two-buffer path output bounds, combat target selection, coordination,
detours and observer execution files were compared byte-for-byte with the
working backup and match. Existing map-teardown guards remain.

The only new movement is a 1.2-second diagonal backstep after a second stall
within 12 seconds and 192 horizontal units. Normal first-stall recovery
stays unchanged. Side choice varies by bot and attempt; no new route/target
blacklist, path cache or waypoint generator is used. It applies only to
legacy pilot mode 6/Human hull. Death/hull/map changes clear the new state.
`bot_escape_recovery` defaults to 0; 1 enables this behavior. Setting it back
to 0 disables the added movement immediately. BOT_ESCAPE records activations.

All 20 standalone tests pass (17 previous plus 3 physical-recovery tests),
the distribution build succeeds, and git diff --check passes. The existing
unused-import warning in shared bindings is unrelated. No new native API
or memory layout binding was added.

Isolated test: `nslog2026-10-24 15-56-07.txt`, Eden followed by Wargames,
8v8, aim error 0.80, coordination 1. The harness and synthetic preset JSON
remain only in the isolated profile. Everyday loadout saving is unchanged.

## Observed results and deployment

Both maps spawned 15 bots (30 joins total), with zero logged script errors,
access violations or panics. Map transition and 440-field test-loadout
restore succeeded. BOT_ESCAPE recorded 35 escalated recoveries.

| Map | Bot samples | Alive samples | Low-movement samples | Route failures |
|---|---:|---:|---:|---:|
| Eden | 538 | 463 | 31 | 4 |
| Wargames | 549 | 462 | 16 | 5 |

There were 307/309 alive samples with speed over 100 units/second and 90/121
engaging samples on Eden/Wargames. These confirm activity, not improved
player experience. Disabled baseline low-movement counts were 1/29. Results
are mixed: Wargames was lower while Eden was higher. Random spawns/encounters
prevent attributing either change to this patch. No general improvement or
better FPS has been established.

At 16:00:43 the everyday solo DLL was updated and bot_escape_recovery 1
enabled as a reversible trial. Regular Program Files stays v12. Normal 8v8
Eden was reopened; no test harness/synthetic JSON was copied. Solo aim error
remains 0.80 and the local loadout add-on is unchanged.

Everyday handoff log: `nslog2026-10-24 16-00-44.txt`. At 16:01:30 it restored
and saved 440 named fields. By 16:02:26 all 15 bots were sampled, with no
logged script errors, access violations or panics. This is a startup check,
not proof of a better full round. The v15 DLL hash was checked on deployment.

These short, random encounters
with a stationary human cannot establish a general gameplay improvement;
position samples lack walls/terrain/video and can miss brief actions.

## Working backup and rollback

`backups\working-v12-before-recovery-20261024-151754` contains the verified
working source and runtime files. DLL v12 SHA256:
`1183389B692F59758C569631F0C7BAB50703C7FB425212876DBB5ABB8DBE7D7A`.
Close Northstar, then run `Restore-Working-V12.cmd` to restore the solo bot
DLL/config/launcher. The rollback verifies the DLL and preserves current
local loadout saves and their script add-on. Full original profile/source
copies and a SHA256 manifest are in that backup directory.
