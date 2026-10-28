# v21 safety candidate — isolated tests only

## Current October28 state

User renewed implementation/testing authorization while away. The restored
build-source script matched its reviewed hash, but optimized/stripped helper
builds continued to fail. The repository's existing **release-debug** profile
successfully built the unmodified pinned dependency graph with the original
Cargo.lock (`--locked --offline`), antivirus enabled and no security setting
changes. This is a debuggable candidate, not clearance of old quarantined files.
Reproduce from the root using nightly2025-09-11 GNU/LLVM-MinGW:
`cargo build -p bp_ort --profile release-debug --target x86_64-pc-windows-gnu --target-dir target/v21-debug-validation --locked --offline`.

First candidate DLL SHA256:
`BE33537CCF312D9249D60249716F7FD9E7502296FBD9B7B9D4D1D5AB90008204`.
Only the working isolated profile was changed; it is now restored to v20.
Normal play remained v20 throughout.
Fresh backup: private `before-v21-testing-20261028-061528`.

First smoke `safety-20261028-062743` passed functional switch-off/respawn/lobby/
new-map checks with no detected errors, but **failed the gameplay improvement
criterion**. Eden90scontrol:2enemyfrag kills/4self;180ssafety:0enemy/12self.
Meadow100ssafety:1enemy/18self. Different durations/lives are not a causal rate
comparison, but they provide no justification for deployment. See first-smoke
derived review. Human was an invulnerable active pilot with15bots in those
initial smokes; later bot-only tests are explicitly separate.

The first release logger read the current active weapon after the signal, which
was often already the primary. Its inferred release weapon/age are invalid.
Source1.2 corrects attribution using the offhands' preparation state and adds
owned-projectile observations. The next-frame any-projectile scan with
originalOwner fallback is now returning owned frag trajectories. Empty queries
in the earlier second smoke remain invalid trajectory evidence. The later
bot-only-r1 report has16bots/inactiveobserver, maps, harness hashes and native/
bridge provenance. Its functional lifecycle checks passed, but Meadow still
recorded20frag self-kills/1enemy kill in100s; it is not suitable for deployment.

Refined candidate SHA256:
`55E02604C81FFE48A768A38BC7299304B26EC66C08A8E0B9F848F80E0A785CCA`.
It tests0.45s bounded toss input,0.85s action ownership, and finishing a started
input pulse when the same freshly reported offhand becomes busy. Starting still
requires explicit readiness. Legacy default-off readiness behavior is retained.
Phase/A-Wall/Pulse tosses gain bounded ownership; a tactical cannot erase the
frag movement brake.94Rust unit checks across18suites passed; all four migration/
preset fixtures passed after game shutdown. Private run safety-20261028-070247
passed all five functional phases and lobby/map transition, with zero detected
runtime errors. It FAILED safety improvement: Eden90scontrol1enemy/6self frag
kills versus180ssafety0enemy/13self; Meadow100ssafety2enemy/18self. No Phase
entries were observed, including the separately marked hurt probe. Counts are
not matched throw trials; retained useful throws and a safety improvement were
not shown. See bot-only-r2/safety-review.json. Both profiles are back on validated
v20 native/bridge1.0, and remaining13baseline maps resumed in a separate queue.
Keep this experimental source behind default-off switches. Different native
hashes must not be pooled despite their shared candidate build label.

Public-source research: research/public-bot-systems-20261028/FINDINGS.md.
No normal deployment until safety outcomes, preserved useful throws, life/map
transitions and current saves pass. Historical notes below describe the earlier
blocked draft and are superseded by this current status.

Update: BT-7274 asked about proceeding despite likely false positives. A verified
local Cargo `links` metadata override successfully skipped the 0.52.6 helper,
but the older 0.48.5 helper was also blocked. A source generator,
`tools/Build-VerifiedWindowsCandidate.ps1`, was then written to verify both
archives and supply both library search paths directly. Antivirus quarantined
that PowerShell script before it ran; BT-7274 confirmed the additional alert.
Its file is absent, so it is not included in this branch. No new DLL or runtime
result exists. No antivirus settings or quarantine contents were changed.
Recommended smaller scope if BT-7274 elects to allow reviewed source: allow
only that exact generator script, leave the discovery EXEs quarantined, and
recheck the restored source before executing it. Do not recreate it under
another name or repeatedly retry blocked files. Whole-PC protection need not
be disabled. This is an authorization choice, not confirmation of a clean
quarantined executable.

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

Static follow-up: basic_combat currently clears a rejected offhand bit but does
not explicitly set a bit for a successful keep_request when the original skill
policy omitted it that frame. Thus pure Pulse continuation is not proof of a
continuous engine input. Before another timing trial, fix/test command-bit
application and record actual held/released inputs. The failed r2 result does
not rule out action interruption as a cause. Do not deploy this experimental
path or generalize its negative outcome to the complete task-ownership concept.
