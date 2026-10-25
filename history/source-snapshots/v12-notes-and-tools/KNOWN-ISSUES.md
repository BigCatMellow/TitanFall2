# Known issues and recovery

## Bot limitations

- The legacy navigation mesh can miss pilot rooftops, obstacles, and airborne
  opponents. A failed route query can be followed by a successful recovery;
  failure count alone is not the number of permanently stuck bots.
- A short burst of recovery jumping can be legitimate. Repeated failure at
  the same position, high turn travel, and ten seconds without displacement
  are more useful signals to investigate together.
- Target sharing and spacing improve allocation, not squad-level planning.
  Bots do not yet have coordinated flanking routes or human-like squad orders.
- Titans retain legacy behavior; experimental OctBots Titan prototypes have
  not been validated here.

## If something goes wrong

1. Close Northstar normally before replacing DLLs. Confirm no test process is
   still running if Steam stays on “Stopping”. Do not terminate unrelated
   Steam or EA processes indiscriminately.
2. Double-click Capture-Latest.cmd to save the newest solo log and replay.
   The original logs are under the solo profile's `logs` directory. A `.dmp`
   beside the log is valuable for an actual native crash.
3. To restore the previous 8v8 solo build, close the game and run
   Restore-Previous-Solo.cmd. It restores the backed-up v11 DLL, solo config,
   and launcher; it verifies the DLL hash and does not erase saves.
4. See CURRENT-SETUP.md for exact hashes and profile paths. The regular
   Program Files profile has its own DLL backup, which may require elevated
   filesystem access to restore.

`C:\Users\james\northstar-crash-audit\Read-CrashDump.ps1` can inspect dumps.
Its raw stack-pointer candidates are not a trustworthy unwound call stack.
Keep matching DLL debug symbols and the exact build hash when interpreting one.

Avoid `ns_resetpersistence` as a generic troubleshooting step. It previously
crashed a session and changes player persistence. Do not reset saves merely
to investigate a navigation problem.

## Observer limits

The observer records game-state samples, not a video or screen feed. The
replay omits map geometry, so two nearby points can still be separated by a
wall. A stall flag is a diagnostic heuristic, not proof of a bug. Short turns,
animations and events between samples can be missed. Older v11 logs have
coarser samples and lack teams, human positions, targets and native alive state.

Comparison runs are short, include random spawns/encounters, and do not prove
causation or long-term stability. No claim of improved frame rate should be
made from the fixed simulation tick interval.
