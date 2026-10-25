# Project status — 2026-10-25

Game closed; automated map testing paused. User requested offline trend review
and complete project import to BigCatMellow/TitanFall2. No game launch/deployment.

| Item | State |
|---|---|
| Installed native plugin | combat-decisions-v16 |
| Installed SHA256 | `C6A60DC54A0B7230A71A5E6D972610B9A500435402CCE4AE868252E7DB191075` |
| Source | observation-v17-candidate; diagnostics, not deployed/runtime-tested |
| Candidate local SHA256 | `9FB6E5ACE50E858607D2CD3B04F592ABE45F1C5DB0E99EE54CDAC525DC74E2F9` |
| Candidate validation |34 tests/7 suites;47058-decision comparison; native build passes |
| Population/difficulty |8v8; human+15bots; aim0.78 |
| Survey |5 completed, partial Kodai;17 trials remain; no auto-resume |
| Latest played session |2026-10-25 12:03:27; Eden/Exoplanet/lobbies; clean shutdown12:21 |
| Data work |Phase-aware review of16 recordings across10 maps; played/controlled/partial cohorts separate |
| Latest analysis |235 deduplicated overhead target bursts;213 show descent,22 lack adjacent follow-up; watchdog timer-context reproduction and five strict compatible log cases |

Recorded stalled pilot samples: Crash Site0.42%, Angel City0.85%, Drydock1.09%.
Eden6.23–8.38% has a repeated shared route hotspot; Complex has a concentrated
slot11 case. These are sample fractions, not incident rates or FPS benchmarks.

Other leads: separate pilot/Titan target switching; cached ammo during boarding;
XY-only range checks admitting distant overhead targets, apparently incoming
Titans. Bot weapon data is mostly R-201. Existing human reload/cooldown changes
are separately validated; broad damage/ability buffs lack outcome evidence.

See research/trends-20261025/FINDINGS.md and
research/decision-context-20261025/FINDINGS.md. Current instruction is organize data
and identify good/bad trends before further gameplay changes. No new gameplay
patch was made after that instruction. Historical archives include rejected
builds; current status/deployment records establish what is live.
