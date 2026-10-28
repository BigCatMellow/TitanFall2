# Partial overnight Full v20 survey

Nine of 22 planned maps completed: eight recorded by the controller plus Glitch
recovered from its independently completed child run. All nine reached the
75-point limit with 16 bots in 8v8 and the human inactive. About 57.6 minutes
of active round time and 19,657 live pilot samples were recorded. The game is
closed; 13 maps have not run. No normal save change was reported by the guard.

The controller stopped at 22:38 on October27 because a status-file Open hit a
brief missing-file publication gap. Glitch continued independently to 75–46
and restored the isolated profile at 22:42. This was an automation read failure,
not evidence of a game crash. Original failure records remain unchanged; the
private recovered-coverage snapshot includes only completed, restored children.

## Findings

- No script/native error markers were found in the nine completed saved logs.
- Bot-pilot frags were credited with 71 enemy pilot kills and **153 self-kills**.
  This independently supports grenade safety as the highest-priority v21 fix.
  It does not identify cooking, release, collision or movement as the cause.
- Other bot-pilot ordnance enemy kills: electric smoke10, Firestar2, Arc1,
  Gravity Star2. Callback/death counts are not throws, accuracy or Titan damage.
- War Games had the highest sustained navigation low-progress fraction,5.91%;
  Eden3.76%, Relic2.74%, Rise1.46%. Glitch, Homestead and Boomtown were below0.5%.
  These overlapping sampled windows are not independent incidents. War Games'
  old1664,-256,128hotspot recurred across five slots.
- Eight rounds favored IMC, including some large margins. One round per map
  cannot establish faction bias or fair human difficulty. Preserve aim/damage.

This frozen Full v20 bot-only cohort remains separate from played v20/v19 and
the historical v18 survey. [Round metrics](rounds.json), [table](REVIEW.md),
[ordnance outcomes](grenades.json). Raw logs, saves and account data stay local.
Metric/source limits and per-log provenance hashes accompany the round report.

## Controller repair

Read-SurveyQueueJson now retries missing/sharing and partial-JSON reads for a
bounded ten attempts with100ms spacing. Persistent errors still stop the queue;
permission errors fail immediately. Four regression cases passed: publication
gap, partial JSON, persistent missing file and permission denial. No gameplay
settings, DLL or saved progress changed during this morning review.

For continuation, the private recovered-coverage status/plan under the original
batch provides nine completed results with the same frozen runtime hashes. Use
that as completed_batches in a NEW request; do not rerun or overwrite old data.
No queue has been restarted during this status review.
