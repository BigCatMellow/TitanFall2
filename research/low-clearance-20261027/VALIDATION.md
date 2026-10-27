# Source validation

Base inspected:1ae9d73853dbced202f0866176f4606846b69913.

- PASS:54 native-independent Rust tests in10 suites, including8new clearance
  policy regressions, using pinned nightly-2025-09-11 on Linux. Also passed all
  checks with Rust1.90 before obtaining the pinned toolchain.
- PASS:Windows-target cargo check -p bp_ort --locked, pinned nightly and
  x86_64-pc-windows-gnu, isolated GCC MinGW cross compiler. Existing shared
  unused-import warning remains; no new compile error.
- PASS:distribution DLL cross-build using the pinned nightly, Windows GNU target
  and GCC MinGW on Linux (not the owner's validated Windows LLVM-MinGW host).
  PE32+x86-64 DLL; SHA256
  bc1c603096d4d23c9ce5568e0acf81a087c53e956806418c7b6886bbee9f85ac.
  Build is not runtime validation. Binary is not committed/published.
- PASS:independent read-only source review and re-review. First review caught
  heading/stale-probe resets bypassing attempt bounds; fixed with abort/cooldown
  and regression coverage. Review also led to actual-command telemetry and
  one-ray early exit for open lanes. Reviewer independently ran8new tests.
- Runtime NOT RUN:actual collision/hull fit, crouch/slide posture, passage time,
  pickups/lifecycle/map transitions, server trace cost, normal deployment.

The first dependency check stopped because MinGW GCC was absent; the isolated
cross compiler resolved that environment dependency before the successful check.
System package installation was unavailable; build tools were installed only in
scratch. These setup failures are not gameplay failures.

No game/profile/config/save was accessed or changed. Deployment is blocked on the
isolated acceptance protocol in README.md, not on any claim of proved bot benefit.
The new BOT_CLEARANCE records require retaining the private raw test log; older
survey/played analyzers do not compute crouch traversal outcomes or archive this
new diagnostic automatically. Do not mistake existing analyzer output for those
new measurements.
