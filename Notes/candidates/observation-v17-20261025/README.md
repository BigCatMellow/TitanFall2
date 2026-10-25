# Observation v17 candidate — NOT DEPLOYED

Prepared alongside the frozen v16 all-map survey. The active game profiles
still contain v16, SHA256
C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075.
The checkout and its build output now contain this diagnostic candidate;
do not assume target/distribution is the installed build.

Changes are confined to diagnostics:

- BOT_DECISION appends actor=pilot/titan using the exact command's existing
  actor classification, avoiding the old two-second context ambiguity.
- BOT_COMBAT appends active=0/1. A new flag clears at the beginning of each
  bot command and sets when the existing combat decision block refreshes
  its snapshot. A bypassed boarding/pet-Titan command reports cached values
  as inactive, even if a paused game clock has not advanced.
- The startup build label distinguishes this candidate from v16.

Target selection, aim, movement, reload decisions, navigation ownership,
engine offsets, configuration and persistence behavior were not changed.
Existing parsers ignore the added fields; Review-TargetSwitches.ps1 preserves
them, labeling older v16 fields unknown rather than inventing freshness.

Validation: all34 native-independent tests passed across7 suites; distribution
build with debug symbols passed. The before/after combat comparison exercised
50000 commands (47058 evaluated decisions, with bypasses, clock resets,
paused times, invalid geometry, weapon/ammo changes) and produced identical
combat decisions and original public state/counters. This is not a native
runtime test or proof of gameplay improvement. The candidate still needs a
real isolated match after the all-map queue, including a map transition and
verification of both new log fields. Do not replace the loaded/frozen DLL.

Candidate DLL SHA256:
9FB6E5ACE50E858607D2CD3B04F592ABE45F1C5DB0E99EE54CDAC525DC74E2F9.
verification.json records tests and source-candidate.zip hash. before/after
contain the4 touched source files; source-candidate.zip contains the full
local tracked/untracked source, preserving earlier fixes. Tests/build logs
and the differential comparison source/executable are retained here.

Built with one compiler job at below-normal process priority while Crash
Site's survey trial ran. The survey is not a controlled FPS benchmark;
record this overlap if later comparing wall-clock performance.
