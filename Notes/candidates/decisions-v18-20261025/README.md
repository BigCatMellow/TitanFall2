# Decisions v18 — implementation and runtime validation

User authorized implementation/testing and then resumption of the map survey.
Normal now uses the tested v18 build. The existing isolated profile passed the
full client suite and final readiness retest before deployment at19:48EDT.
Native DLL SHA256: `F3C41DE2D11C84959454A16C8DCE9ED8B03BCD5E05E59090E32E87C6B78F3648`.
Final bridge SHA256: `30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78`.
Local binaries and saved-state backups are excluded from publication.

Private backup before edits: `implementation-v18-20261025-141109`, under the
machine's audit Notes/backups directory. Both deployment DLLs matched v16
`C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075`.
Current personal saves, configs and authored add-ons were copied, not restored
from an earlier survey. No raw persistence/reset command was used.

## Implemented candidate

- Separate default-off switches for navigation context, pet-Titan eligibility,
  pilot offhand readiness/pulses and opposite-side combat stepping.
- Watchdog anchor resets after non-navigation commands, and on death/hull
  changes; genuine continuous navigation retains the original stall threshold.
- Script bridge reports engine readiness, resource availability and hotdrop
  state every0.1s. Native samples require matching handles and expire at0.35s.
  The bridge resets on map teardown and bounds stale entity accumulation.
- Coordinated pilot targeting excludes unavailable/hotdropping pet Titans before
  both visible selection and pursuit fallback. Other target paths are unchanged.
- Offhand requests are bounded to0.12s, with one pulse start per second per
  weapon. Existing health/timing eligibility remains; tactical has priority over
  ordnance. Ready Stim/Phase intent survives reload suppression; engine cooldowns
  remain unchanged. Grapple/A-Wall automation remains outside this candidate.
- Combat stepping may retry the opposite side with the same wall/ground checks,
  and stops if both are blocked. `blocked_steps` now counts an entirely blocked
  step when retry is enabled; it is not directly comparable to the old chosen-
  side failure count.
- Retains v17 exact actor/cache-freshness diagnostics and adds actual current-
  weapon, readiness, resource/shot observations and issued-input diagnostics.

Aim0.78, normal8v8, current human loadouts,50% human tactical recharge and
four-gun0.9reload modifiers are unchanged. Mixed bot weapons/suits exist only in
the disposable test harness; they are not a proposed default loadout change.

## Offline checks

41 tests in8 suites pass; native distribution build passes. A comparison using
the **current source** evaluates47058 combat decisions across50000 commands
against v16: identical decision outputs/state/counters. It covers the pure
combat controller, not the newly changed native integration.
`tests/compare_combat_current.rs` imports the current canonical source. The old
v17 comparator remains an archive, not evidence that current source was tested.

## Startup investigation

Initial client attempts did not reach a match. One watcher incorrectly treated
an external online-auth warning as fatal; it now records that exact warning and
still stops on script/compile/native errors. A UI debug probe briefly contained
an unsupported GetMapName call; removed before further tests.

The previously working v16 DLL in the same disposable profile also stalled.
Dedicated startup exposed a missing persistent definition; BT-7274 confirmed the
same client dialog. A temporary test-only filesystem/schema preflight got past
that error, then exposed missing core script functions. It has been REMOVED.

One confirmed setup error was the agent's incomplete fresh-profile copy: it omitted the
profile's Northstar.dll. The launcher source explicitly falls back to the game-
root DLL when that file is absent. Startup logs showed1.30.2.0, while the working
profiles use1.31.14.0. The older core also wrote boolean enabledmods entries;
only the new add-ons appeared in its compiled mod-script list, leaving the
copied1.31.14 core scripts unavailable. These failures are invalid AI trials.

Corrected the profile by copying the exact matching working Northstar.dll and
regenerating the versioned enabledmods file from its installed manifests. Removed
the temporary schema override, native search-path/prewarm code and automatic UI
map retry. No schema changes or base-game writes are retained. New launcher and
watcher verify the real core version to prevent repeating this setup mistake.

The fresh clone still failed startup after that correction; its remaining setup
issue is unresolved. It was abandoned. A v16 control worked in the original
isolated profile; that profile was backed up before staging v18. Dedicated
attempts did not produce valid matches. Neither startup failure is AI evidence.

## Runtime gate

Required: baseline/new switches,16bots8v8, varied ability/weapon inputs, map and
lobby transitions, human+15bots return, current-save protection and error review.
The full client suite `decisions-v18-20261025-153058` passed at15:48EDT:
five16-bot8v8 phases, Eden/Complex/Canal, progressive switches, six primary weapon
classes, seven suit inputs, lobby return and normal human+15bot population.
No detected script/compile/native errors. See [runtime review](RUNTIME.md).
Known-hotdropping pet selections:11 sampled baseline selections,0 with the
eligibility filter. This is sampled integration evidence, not a controlled
balance comparison. Tactical resource drops and issued pulses were observed;
shot counters alone did not establish casts.

A final ammo-per-shot cost refinement initially failed compilation because its
helper declared int while the API returns float. Fixed to float. A subsequent
quick launch was intentionally stopped because its arguments selected phase0;
the launcher now sets phase/quick before +map. Final retest is
`decisions-v18-20261025-194409`: matrix, lobby, human+15bots with the same native
DLL and final bridge; PASSED at19:48EDT. It recorded866cost samples, including
38unaffordable tactical observations and0incorrectly-ready samples. See
[final readiness review](readiness-retest/RUNTIME.md).
The earlier full suite used the previous shared-energy
cost calculation; the final retest specifically covers the refined script.

Normal deployment requires both passed runs and exact DLL/bridge hashes.
Current normal saves get a new backup and are hash-checked during deployment;
older baseline saves are never restored. Old v16 reports remain separate from
the new candidate survey. No claim that this fixes all map geometry or improves
win rates has been established.

## Final deployment and survey

`tools/Deploy-TestedDecisions.ps1` installed the exact tested files into
`local-test-profile` after both runtime gates passed. Fresh rollback backup:
`before-v18-normal-deploy-20261025-194834`. All3current normal save files were
hash-unchanged during deployment and rechecked afterward. All25files across
the four existing authored gameplay add-ons match the initial backup. Existing
aim/population/human modifiers and the solo launcher are preserved. The test
harness was not installed in normal play.

The fresh22-map queue `decisions-v18-all-maps-20261025-194900` is running in
`map-cycle-test-profile`, starting Kodai. Verified16bots8v8, observer dead,
engine score goal200, and advancing kill/score heartbeats. Every map gets a
fresh process; the old v16 cohort stays separate. Initial state is recorded in
[survey-start.json](survey-start.json); use live private status for current state.
One installed arena lacking navigation data remains explicitly excluded.

[verification.json](verification.json) records tested/installed hashes,
save/add-on guards and LF-normalized source hashes. Builds in another directory
or toolchain need not reproduce the same binary hash. Private raw logs, saves,
runtime binaries and backups remain outside the public repo.

## Rollback

With the game fully closed, use the new `before-v18-normal-deploy-*` backup
recorded in the final handoff. Restore only its plugin DLL, server.cfg and
enabledmods.json to the same normal-profile locations. If the bridge did not
exist before deployment, explicitly set
`"BT7274.BotDecisions": {"1.0.0": false}` in enabledmods.json; absence alone may
auto-enable an installed mod. If it existed, restore its backed-up source too.
Do not copy backup save_data over current progression/loadouts. The first
implementation backup and old checkout remain available as historical fallbacks.

## Survey control

The new runner owns only its exact isolated profile/PID and stops the queue on
an engine/script error, missing heartbeat, invalid population or changed frozen
runtime hash. Each map starts in a fresh process. To pause safely, create an
empty `stop-after-current.txt` in the active batch directory from the handoff;
the current map finishes and the runner restores the pre-survey configuration.
Do not edit a loaded DLL or start a second game while the queue is active.
