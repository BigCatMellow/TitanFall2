# Local bot crash investigation

The repeated access violation is a native pathfinding output buffer overflow.
It is not established to be a client-connect detour failure. Earlier local
patches that disabled that detour and skipped initialization were speculative;
they have been removed from `bots/mod.rs`.

## Evidence

The preserved guarded build crashed at RVA `0x2ab2c`, while reading
`helper.globals.curTime` in `bots/cmds_utils.rs::path_to_target` after
`Navigation::new_path`. Its caller returns at RVA `0x473f5` in bot simulation.
The clock pointer was corrupted. The instruction is `movss 0x10(%rsi), %xmm0`.

The installed Titanfall 2 `server.dll` implements `findPath` at RVA `0x3ec310`.
At `0x3ec96b` it writes one polygon reference per path step to argument 7.
At `0x3ec974` it writes one byte per step to argument 8. `maxPath` bounds BOTH
buffers. The plugin incorrectly typed argument 8 as an unknown const pointer
and passed the address of an immutable eight-byte local `i64` while advertising
a capacity of 256. Routes exceeding eight polygons write past that stack slot.

## Changes

- Correct argument 8 to a mutable traversal-byte output pointer.
- Give both native outputs equally bounded, initialized allocations.
- Restore both lengths before every query; truncate only after count validation.
- Pass the real traversal bytes to `findStraightPath`.
- Reject negative or oversized straight-path result counts before `set_len`.
- Keep the normal client-connect hook and bot initialization.
- Skip optional name callbacks absent from this standalone installation (noise
  reduction only; their absence is not proof that they caused a native crash).
- Retain debug symbols and log a unique build identifier for crash analysis.

## Regression tests

From this checkout, using the installed nightly toolchain and LLVM-MinGW PATH:

```powershell
& %USERPROFILE%\.cargo\bin\rustc.exe +nightly-2025-09-11-x86_64-pc-windows-gnu --test --edition=2024 tests\navigation_buffers.rs -o target\path-buffers-tests.exe
& .\target\path-buffers-tests.exe
```

Three tests pass: all 256 output steps, repeated short-to-long routes including
9 and 256 steps, and invalid native output counts with unequal capacities.
The mock performs the same two raw output writes as the native pathfinder.
These tests verify the buffer contract; gameplay stability needs a live test.

The defect is also present in the official v1.0.0 source tag (`0439a72`).
This was not introduced by our local guards, although those guards failed to
address it and the earlier attribution to the join detour was incorrect.

## Live validation

An isolated profile at `%USERPROFILE%\northstar-crash-audit\local-test-profile`
uses the normal core mods and the candidate DLL. Its server config disables
public listing and uses Northstar's documented local connection mode. The
launcher binds to loopback on port 37025. The regular installed server config
is unchanged.

At 2026-10-24 11:14:57 local time, all seven bots spawned on Eden, alongside
the local player. Subsequent logs show bot deaths and respawns, with the process
responsive and zero crash/panic entries at 11:15:53. This passes the previously
reliable spawn-crash trigger; it is not a guarantee against every other bug.

Log: `local-test-profile\logs\nslog2026-10-24 11-14-09.txt` in the audit folder.

At 11:17:36, the same match had seven spawned bots, 23 bot-death replay
entries, 28 respawn log entries, zero crash/panic entries, and a responsive
process. The full lobby remained running for more than 2.5 minutes after the
seven bots joined. The local launcher `Play-Solo-Bots.cmd` in the audit folder
reopens the same profile and automatically fills to eight total players.

## Build and recovery

The installed candidate is built with `--profile distribution --locked`, with
`CARGO_PROFILE_DISTRIBUTION_STRIP=none` and
`CARGO_PROFILE_DISTRIBUTION_DEBUG=2`. OctBots is absent.

Build identifier: `navigation-output-buffers-v1`.
SHA256: `BF14476DCC5770FFBA0FED6DE56CF0E038C105A1EBA240587D507BACFF130109`.

Candidate and prior hook-disabled DLL are preserved under:
`%USERPROFILE%\northstar-crash-audit\navigation-fix-v1`.
The full prior Northstar install remains in the dated Documents backup.
