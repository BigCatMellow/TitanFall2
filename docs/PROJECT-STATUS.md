# Project status — 2026-10-28

Normal now has the tested **v23 Eden-only pilot route repair**, native BC2C1019... .
It preserves pending waypoints and temporarily routes around a failed type16
jump near its failure location. The reproduced Eden hotspot cleared in both
repair-on trials; off trials remained blocked. Respawn, disable, lobby and
Complex map change passed, with repair inactive on Complex. Six current saves,
enabledmods and existing gameplay settings were preserved. Same solo shortcut.
See [findings and limits](../research/route-continuity-v23-20261028/FINDINGS.md).
Isolated is restored to v20; no game/test queue remains. Later choke points and
human combat validation remain open. Global experimental switches stay off.

The reviewed v20 stack remains the gameplay/modifier foundation.
Use the existing solo shortcut: default Movement enables combat movement and the
proximity correction. [Presets, evidence and rollback](../Notes/candidates/bot-capability-v20-20261027/README.md).

Latest played Full review: [four-round findings](../research/played-full-v20-20261027/FINDINGS.md).
Combat movement is much more active; actual grenade damage is recorded, but
frags caused 103 self-kills versus 37 enemy pilot kills. Eden still has recurring
route stalls. Phase/A-Wall activation remains unconfirmed. Review only: no game
settings or saves changed, and no aim/damage adjustment is justified here.

| Item | Current state |
|---|---|
| Native |v23 Eden-only route repair, BC2C1019...; v20 rollback3077878B...|
| Native SHA256 |3077878B8FDA814F8F50488BE4C073E040AC60A7E8BB45F053AF95D488DF1D89|
| Core |Northstar1.31.14.0|
| Profiles |Normal Movement; working isolated candidate Baseline; test harnesses disabled|
| Preserved |8v8,human+15bots,aim0.78,existing0.8sfiring warm-up,damage/RPM|
| Human changes retained |Tactical recharge0.5,five-gun reload0.9,ADS/role trials; bot weapon-balance opt-in0|
| Naming/save migration |BT7274 add-ons;902restored fields;0preset-definition changes;3old normal saves unchanged|
| Current package fixes |Solo.WeaponNotes1.1.1,BT7274.BotRoster0.1.1; version-aware migration/rollback|
| Offline |86Rust tests/17suites,47Node tests/9suites,migration/rollback/versioned and preset fixtures|
| Compatibility |16bot observer phase,11gun classes,32human modifier/control/strip cases,lobby/human+15return|
| Staged smoke |8roster primaries/6tacticals;skills/height/personality;switch-off,respawn,lobby/new map,cancelled assignment restored|
| Live rollback |v19/native+old add-on family started with902fields/current progress and no errors, then candidate restaged|
| Normal shortcut |Actual WindowsPowerShell Movement launch,62same-frame8v8observations,no runtime errors; collector complete44pilot deaths/5qualifying episodes|
| Gated OFF |Crouch recovery,route guard,jump timing,perception correction,view-kick sampling|

`Play-Solo-Bots.cmd baseline` is the immediate behavior rollback. Cumulative
height/roster/skills/full presets are available for deliberate comparison. The
normal launcher resets to Movement each start. Preset selection atomically writes
only the trial switches, records metadata and backs up previous server config so
autoexec cannot silently overwrite a requested trial. No game is left running
from verification. Current gameplay progress stays in the normal profile.

The sampler is read-only magazine expenditure, not accuracy. Skill requests are
not confirmed casts. Diagnostics showed plausible72/47stand/duck hull heights and
109raw view vectors matching forward direction, not raw degrees. Perception
therefore remains off. Short mixed diagnostic phases do not establish route/crouch
success, fairness, K/D balance or FPS/p95 performance. The3:1human pilot K/D target
still requires human map pairs/feedback; no claim it has been achieved.

Backups: before-v20-normal-20261027-175459 (normal cutover),
before-v20-20261027-165920 (initial profiles/failed-attempt history), under private
audit Notes/backups. Full restore uses the ORIGINAL migration backup and carries
CURRENT progress back. Never copy historical save_data over newer play.

The v19 weapon rollout and completed22-map v18survey remain historical cohorts.
See research/played-weapons-20261026 and research/maps-v18-20261026 for prior
findings. No live visual watching occurred. Private raw logs, account data,
personal saves and binaries remain local; source and aggregate evidence are public.
