# Handoff for future work

Read CURRENT-SETUP.md, HISTORY.md, and the latest session's `metadata.json`
and `summary.json` before changing anything. Check the running executable,
its profile, the newest log's build ID, and installed DLL hashes. Old reports
are historical observations, not proof of the current installation.

## What BT-7274 asked for

1. Improve organization: reduce dogpiling, target churn, and teammate crowding.
2. Observe actual bot behavior more closely, not merely successful bot joins.
3. Keep notes, logs, backups, and a reproducible way to resume or recover.

The working reference was v11 in an 8v8 solo match, aim-error multiplier 0.8.
The user last played Glitch successfully but still saw navigation problems.
v12 adds team-local pursuit claims and structured observation; its current
deployment/test status is in CURRENT-SETUP.md.

## Source and build

Checkout: `%USERPROFILE%\bp-ort-fork`. Upstream:
`https://github.com/catornot/bp-ort.git`, base HEAD `2d0a559`.
Changes are local and uncommitted; no GitHub fork/PR has been published.
Preserve existing edits. The source archive plus working checkout are both
needed context; do not reset the repository to upstream.

PowerShell build:

```powershell
$env:CARGO_PROFILE_DISTRIBUTION_STRIP='none'
$env:CARGO_PROFILE_DISTRIBUTION_DEBUG='2'
$env:PATH='%USERPROFILE%\Downloads\llvm-mingw-20261020-ucrt-x86_64\llvm-mingw-20261020-ucrt-x86_64\bin;'+$env:PATH
Set-Location '%USERPROFILE%\bp-ort-fork'
& '%USERPROFILE%\.cargo\bin\cargo.exe' +nightly-2025-09-11-x86_64-pc-windows-gnu build -p bp_ort --profile distribution --locked
```

Output: `target\x86_64-pc-windows-gnu\distribution\bp_ort.dll`.
Keep debug symbols. Run `tools\Test-BotBuild.ps1` from this notes folder and
`git diff --check`. There are native-independent tests for two-buffer output
bounds, jump release, movement progress, wrapped steering, and coordination.

## Deployment and observation

- Back up the active DLL, solo autoexec, and launcher before replacing them.
- Run new native candidates in the isolated profile first. Its separate cycle
  harness can change Relic to Wargames. Keep actual bot count and aim settings
  the same when comparing coordination on/off.
- Game writes in Program Files and normal desktop game launches may require
  the terminal tool's sandbox escalation. Restricted game launches produced
  a video-mode warning; normal desktop launches worked. That warning was not
  evidence of a bot crash.
- If stopping a test session, match its exact profile in the process command
  line and wait for process exit before replacing a loaded DLL.
- Only ship a build after tests and a real match check. Check movement,
  combat, team sizes, map-change cleanup, and absence of errors. A clean
  crash log alone is insufficient.
- Export logs with `tools\Export-BotSession.ps1 -LogPath '<log>'`. All reports
  stay local. The replay does not contain game terrain or video.
- Update CURRENT-SETUP.md, HISTORY.md, and session results after deployment.

## Important boundaries

The confirmed old crash was a native pathfinder buffer overflow. Disabling
name callbacks/client hooks was speculative. Authentication failure was an
external DNS failure at the time it was investigated; a reinstall coincided
with recovery and did not establish causation.

OctBots is an optional experimental rewrite. Read OCTBOTS-ASSESSMENT.md in
the source checkout. It needs matching plugin builds and its own navigation
data. Full OctBots navigation and a pilot/legacy-Titan hybrid have not been
validated. Team coordination does not repair missing map navigation coverage.
