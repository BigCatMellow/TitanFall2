# Northstar solo bot workspace

This is BT-7274's live bot development checkout. Before continuing, read:

- `%USERPROFILE%\northstar-crash-audit\Notes\CURRENT-SETUP.md`
- `%USERPROFILE%\northstar-crash-audit\Notes\HANDOFF.md`

Keep the user's selected 8v8 population. Latest aim-error choice is 0.78,
a tiny step from 0.80 saved on 2026-10-24; verify current runtime logs before
assuming the staged setting is live. See REVIEW-20261024-1958.md in Notes.
Preserve local edits and confirmed native
buffer/map-lifecycle fixes. Back up DLLs and configuration before deployment.
Test native candidates in the separate profile, verify movement/combat and
map transitions, and distinguish observation from hypotheses. Update the
notes and build hashes after changes. The notes contain exact build commands,
rollback paths, logs, known limitations, and previous failed approaches.
