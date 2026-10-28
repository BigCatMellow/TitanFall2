# v21 safety source draft — not built or installed

BT-7274 authorized the follow-up changes after the first Full review. Work
stopped when antivirus quarantined a Cargo build helper with detection
`Gen:Variant.Lazy.746108`. **No v21 DLL exists, no runtime validation passed,
and neither profile was upgraded.** Both installed DLLs still hash to
`3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89`.
Normal and Full shortcuts still use v20 and current saves.

Current private backup: audit parent
`Notes/backups/before-v21-20261027-203256`, taken before any source work.
Includes both profiles' current DLLs, core, enablement, receipts, saves,
bridge/roster packages, server config and the normal launcher. Do not restore
historical saves over subsequent play.

## Draft changes

- Default-off `bot_offhand_safety`, subordinate to `bot_skill_use` and the
  readiness gate: frag minimum target distance 550 units, cached three-ray
  nearby throw clearance, fixed throw aim for 0.85 seconds through wind-up/
  release, no conflicting gun attack/reload/melee during that interval, and
  a three-second forward approach brake for frags. No new throw during the
  three-second interval, apart from finishing the original short press.
  The approach brake does not feed the navigation watchdog as a false stall.
- Default-off `bot_stall_retarget`: after three local pilot pursuit stalls,
  avoid that pursuit target for six seconds. Visible threats remain eligible;
  original target fallback remains if all candidates are blocked. No map
  coordinates, teleports, navigation-buffer or teardown changes. Escape state
  now resets with other per-life candidate state.
- Bridge source version 1.1.0 records observed offhand bookkeeping timestamps,
  weapon attack callbacks and actual phase-state transitions. These signals
  remain separate from requests and from projectile damage. Observation errors
  have a separate three-error budget. The bridge is **not installed**.
- Disposable `BT7274.SafetyTest` plus start/watcher tools draft a same-build
  switch-off control, safety phase, separately marked manipulated-health probe,
  switch-off, lobby and new-map checks. **Harness code has not run.**

Aim, firing warm-up, weapon damage, human modifiers and saves are unchanged.
No launcher presets enable these switches yet. Existing crouch, route guard,
jump timing and perception remain off. Pure Rust suite passed 91 tests across
18 suites plus the existing migration/preset fixtures. The native integration
has not compiled; do not treat offline tests as runtime validation.

## Antivirus investigation

Reported quarantined path is under repo-relative
`target/distribution/build/windows_x86_64_gnu-2189fa6124f67626/build-script-build.exe`.
Four build attempts failed to link/run that helper; a fresh `target/v21`
attempt was made before BT-7274 identified the antivirus alerts. Build attempts
ceased immediately after that report. No cargo/rustc/game process remained.
No quarantine restoration, security exclusion or antivirus configuration change
was performed. Do not retry or repackage the flagged executable while this is
unresolved.

Read-only checks:

- `Cargo.lock` is unchanged. Pinned `windows_x86_64_gnu` 0.52.6 archive SHA256:
  `147a5c80aabfbf0c7d901cb5895d1de30ef2907eb21fbbab29ca94c5b08b1a78`.
- Cached archive has exactly that SHA256. All eight regular files extracted in
  the registry source directory match the cached archive byte for byte.
- Local `build.rs` SHA256:
  `6d40bd2c0ed4cbea5126dfcd89d72f229c7d986540cbf0dc34acc1017f1de20f`.
  Its code reads `CARGO_MANIFEST_DIR` and prints the `lib` directory as a Rust
  native link-search path. It contains no downloading or process-launch code.
- These checks support the possibility of a false positive. They **do not**
  establish that the quarantined binary, compiler/linker or whole system is
  clean. The executable's hash was not captured before quarantine.

Vendor guidance: [update and system scan](https://www.bitdefender.com/consumer/support/answer/2576/),
[quarantine and suspected false-positive analysis](https://www.bitdefender.com/consumer/support/answer/2092/).
BT-7274 should keep the file quarantined while the detection is reviewed. No
file or personal security logs were submitted to any external analysis service.

## Resume only after the antivirus issue is resolved

1. Inspect the source diff, compiler/linker provenance and vendor scan result.
   Preserve the quarantine evidence; do not add a broad exclusion as a shortcut.
2. Resolve the build issue and compile the candidate. Fix any integration errors.
3. Install only in the working isolated profile with its matching 1.31.14 core.
4. Run compatibility, safety/control and ability outcome tests. Require actual
   grenade outcomes and Phase/A-Wall evidence; a phase-pass marker alone only
   shows the harness survived. Diagnose the release/collision cause if self-kills
   remain; do not assume this draft fixed them.
5. Check respawn/Titan/lobby/map transitions, preserved human modifiers, current
   saves, population and errors. Validate rollback. Then deploy a hashed receipt
   and deliberate preset updates to normal play after a fresh current backup.
6. Save derived aggregates separately from the played v20 cohort. Update status
   only when the candidate is actually built, tested and installed.
