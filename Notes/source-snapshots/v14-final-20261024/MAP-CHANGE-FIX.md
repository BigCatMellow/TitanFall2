# Map-change investigation (2026-10-24)

The seven-bot Eden match ran from 11:14:57 through its normal match end.
After returning to the lobby and selecting Relic, the first bot joined during
the dropship intro at 11:27:31 and the process faulted in ntdll. The dump has no
usable unwound call stack. A raw stack scan includes `spawn_fake_player` at
bp_ort RVA 0x382a4 after `ClientFullyConnected`; these scanned addresses are
candidates, not a complete or authoritative unwind.

The final build changes these lifecycle and scheduling behaviors:

1. Bot slots retained Navigation objects across server VM/map destruction.
   Queries own native allocations and refer to the previous map navmesh.
   Shutdown now blocks simulation, clears per-map manager state, and drops
   those queries before the next map. Creation starts with empty bot slots.
   Client pointers are snapshotted before invoking disconnect callbacks.
2. The manager's `is_alive` test becomes true during dropship player setup.
   The first regression runs produced script errors for incomplete persistent
   data or null player script entities while bots joined that intro. The
   manager now reads a readiness convar published by the `BT7274.BotLifecycle`
   server script from normal game-state callbacks. It leaves 0.5 seconds between
   joins so FULL signon does not imply all join callbacks have settled.

3. Fake-client creation previously ran from the general HostState frame
   callback. That entry executes server Squirrel callbacks and must be
   synchronized with server work. The manager now runs after the existing
   server physics callback returns, after bot simulation's state borrows have
   been released. The general frame only records its thread ID for diagnostics.
   The engine supports threaded server execution; initial loading happened to
   report identical engine/server thread IDs in this test, so these IDs alone
   do not prove a concurrent worker race in the failing session. The validated
   change is moving joins to the correct server-update phase.

Installed build: `navigation-map-lifecycle-v7`.
SHA256: `24D2B848E5DF564C034DB983A3516648155722C55F67A9F820DCEF44950E7194`.
The original navigation-output-buffer fix and its three tests are retained.

The isolated `map-cycle-test-profile` uses a separate `BT7274.BotCycleTest`
script to change Eden -> Relic -> Wargames after 25 seconds of each active
match. It keeps seven bots, localhost binding, and no public listing. The
playlist round timer was not sufficient for deterministic cycling, so the test
uses explicit `GameRules_ChangeMap` calls. This harness is not installed in the
everyday profile.

Polling the script VM from the engine frame was rejected in v3/v4 because it
interfered with player script initialization. v5 eliminates that polling
entirely; the server script pushes a signal on its own normal event thread.

The readiness signal alone (v5) still allowed malformed persistence field names
during bot creation from the general frame. v6 moved creation to the physics
frame but initially misinterpreted the native simulation flag and spawned no
bots, so that was not a valid seven-bot test. v7 removes that incorrect gate.

## Passing live test

`map-cycle-test-profile/logs/nslog2026-10-24 12-04-31.txt` records:

- Eden: seven bots joined 12:05:31-12:05:34.
- Eden -> Relic at 12:05:56: seven old navigation queries released.
- Relic: seven bots joined 12:06:20-12:06:23.
- Relic -> Wargames at 12:06:45: seven old navigation queries released.
- Wargames: seven bots joined 12:07:14-12:07:17.
- Test completion marker at 12:07:39; responsive at 12:08:12.
- 21 successful bot joins, zero SCRIPT ERROR/crash/panic entries.

The three path-buffer regression tests pass, and `git diff --check` is clean.
The tested DLL and `BT7274.BotLifecycle` helper were installed in both the regular
R2Northstar profile and the everyday local solo profile. Previous DLLs and a
copy of the passing log are under the `navigation-map-lifecycle-v7` audit folder.
The map-cycle harness is absent from the everyday profile. Its seven-bot target
and aim threshold -1 are preserved. Relic was reopened in that everyday profile
for handoff.
