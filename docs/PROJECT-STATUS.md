# Project status — 2026-10-26

Weapon work from all four user branches is integrated, tested and installed.
See [current rollout](../Notes/candidates/weapons-v19-20261026/README.md).

Automatic text weapon recording is installed through the existing solo shortcut.
The [weapon notebook](../Notes/weapon-notebook/README.md) contains 30 reference
records, conditional ideal models, actual v19 runtime checks and isolated/normal
recorder validation. Normal launch restored 902 fields and human+15 bots with no
runtime error markers. The recorder changes no gameplay variables; 44 existing
gameplay files remain hash-identical. Current progress was retained and preset
definitions were unchanged. This is damage-to-death telemetry, not video,
accuracy or first-shot TTK. Test sessions are closed; the injector is disabled.

| Item | State |
|---|---|
| Installed plugin | weapons-v19-candidate; v18 decision switches retained; 25 standard pilot weapon profiles |
| Native SHA256 |9E8809146E17399B1CE572A5B479846C9A53633C48B7154A02159F47B19A4D6D|
| Readiness bridge SHA256 |30A3B738433A3F04F048C505D1EF04DAF98552D3A943CA6AD32B498264BD0E78|
| Core | Northstar 1.31.14.0, verified in actual runtime |
| Offline checks |46 Rust tests/9 suites;17 Node checks;47,058 existing-controller decisions match v16; native build passes|
| Isolated runtime |11 bot gun classes;32 human/control/bot-strip cases; respawn, lobby and human+15 bot return pass|
| Normal installation |18:36 EDT; startup restored 902 named fields, human+15 bots; all 3 saves byte-unchanged|
| Human trial |Flatline/Volt ADS recoil, R-97 hip spread, Spitfire ADS movement; Flatline/G2 ADS scale0.75|
| Reload correction |Version1.0.1 retains G2/Volt/R201/CAR and adds real Alternator; scale0.9, Speedloader composition verified|
| Preserved settings |8v8, aim0.78, human tactical recharge0.5, damage/RPM/magazine values; bot balance opt-in remains0|
| Map study |22/22 supported maps complete under historical v18, NOT the v19 weapon revision|
| Source candidate |bot-capability-v20 (not built on Windows, not installed): seven default-off switches; see research/bot-capability-20261027|
| Map follow-up |War Games/Eden shared route cells; single rounds and overlapping samples, not a causal comparison|

The normal and isolated gameplay packages match the tested functional manifest.
Test harnesses are disabled. No game is left running. Effective-variable checks
are not visual recoil/ADS measurements, hit-rate tests or proof of balance quality.
The normal startup used real saved loadouts; no old saves were restored.

Current rollback backup: before-weapons-v19-deploy-20261026-183629 under private
audit Notes/backups. Initial complete backup: weapon-integration-20261026-181718.
Close the game before restoring deployment files, explicitly disable the newly
installed handling/balance add-ons when returning to the older setup, and keep
current save_data. The older v18 rollout/backup records remain historical.

The completed map survey and its evidence are in research/maps-v18-20261026.
The new thirty-weapon reference/role assessment is in research/weapon-roles-20261026;
reference statistics remain distinct from installed effective values. No live
visual observation or gameplay recorder was used in those historical studies.
The new text recorder does not retroactively supply weapon TTK for them. Native waypoint-buffer,
teardown and persistence safeguards remain preserved. The abandoned fresh
candidate clone is still startup-broken; use the working isolated profile.
