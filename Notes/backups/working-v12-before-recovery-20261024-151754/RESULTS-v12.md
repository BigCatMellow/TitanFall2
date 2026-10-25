# v12 comparison — 2026-10-24

Build: `team-observer-v12`, SHA256
`1183389B692F59758C569631F0C7BAB50703C7FB425212876DBB5ABB8DBE7D7A`.

Both isolated runs used Relic, one human plus 15 bots, mode 6, and aim error
scale 0.80. The cycle harness allowed 75 seconds of active play before
changing to Wargames. Snapshot durations below also include the intro.

| Relic observation | Coordination off | Coordination on |
|---|---:|---:|
| Snapshot duration, seconds | 90 | 88 |
| Bot observations | 538 | 531 |
| Alive observations | 465 | 449 |
| Target switches | 757 | 289 |
| Recovery attempts | 51 | 23 |
| Failed route queries | 17 | 8 |
| Route requests | 8,475 | 5,849 |
| Low-movement observations | 45 | 9 |
| Observations with at least two nearby allies | 53 | 17 |
| Mean largest share pursuing one target, when 3+ pilots pursue | 0.932 | 0.427 |

The on-run snapshot confirmed teams of eight and eight. Each run recorded
30 bot joins across Relic and Wargames and zero logged script errors, native
access violations or panics. All 17 native-independent regression tests pass.

These are promising short observations, not a controlled benchmark: spawns,
encounters, deaths and Titan use can differ between runs. Focus fire against
an immediate threat is sometimes sensible. A low-movement flag means <50
horizontal units over at least 10 seconds while pursuing/recovering; it does
not prove a bot was permanently stuck. Wall geometry is not captured.

- [Coordination-on replay](sessions/nslog2026-10-24_13-58-30/replay.html)
- [Coordination-off replay](sessions/nslog2026-10-24_14-06-18/replay.html)
- [Earlier user rounds, including Glitch](sessions/nslog2026-10-24_13-21-12/replay.html)

Replay JavaScript passed syntax and mock-DOM/canvas runtime checks, including
bot selection and final-frame rendering. Desktop/browser automation surfaces
were unavailable, so there was no visual screenshot review of the page.

## Everyday-profile Glitch check

The 14:13:53 visible solo launch used the installed v12 DLL, 16-player cap,
coordination 1 and two-second snapshots. By 14:17:25, all 15 bots had joined,
1,116 bot observations were exported, and the game remained responsive with
no logged script errors, access violations or panics. The initial export had
three low-movement observations, nine recovery attempts, and 89 route-query
failures. These are partial-match counts, not directly comparable to the
earlier full Glitch round. [Replay](sessions/nslog2026-10-24_14-13-53/replay.html).
