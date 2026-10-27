# Weapon reference notebook

Generated with `node tools/Build-WeaponNotebook.mjs`; full fields, source revision, assumptions and validated role-field checks are in [catalog.json](catalog.json).

These are pinned reference facts and ideal fixed-damage estimates for a 100-HP body target. They are **not measured current-game TTK**. Near/far columns use each gun's own damage bands; they are not a comparison at one shared distance. Time starts at the first hit, omitting acquisition, ADS, missed shots, travel and tick quantization. Null/inherited fields are unknown, not zero.

| Weapon | Reference damage near/far/very far | Nominal RPM | Magazine | Ideal near | Ideal far |
|---|---:|---:|---:|---|---|
| R-201 | 25 / 17 / 12 | 810 | 24 | 4 hits / 222.2 ms | 6 hits / 370.4 ms |
| R-101 | 25 / 17 / 12 | 810 | 24 | 4 hits / 222.2 ms | 6 hits / 370.4 ms |
| Hemlok | 33 / 25 / 20 | 930 | 24 | Needs dedicated model | Needs dedicated model |
| Flatline | 30 / 20 / 15 | 600 | 30 | 4 hits / 300.0 ms | 5 hits / 400.0 ms |
| G2 | 40 / 35 / ? | 330 | 14 | 3 hits / 363.6 ms | 3 hits / 363.6 ms |
| CAR | 25 / 13 / 10 | 846 | 30 | 4 hits / 212.8 ms | 8 hits / 496.5 ms |
| Alternator | 35 / 18 / 14 | 600 | 20 | 3 hits / 200.0 ms | 6 hits / 500.0 ms |
| Volt | 25 / 15 / 12 | 660 | 33 | 4 hits / 272.7 ms | 7 hits / 545.5 ms |
| R-97 | 20 / 12 / 10 | 1080 | 40 | 5 hits / 222.2 ms | 9 hits / 444.4 ms |
| Spitfire | 35 / 25 / 20 | 540 | 80 | 3 hits / 222.2 ms | 4 hits / 333.3 ms |
| Devotion | 25 / 20 / 15 | 300 | 55 | Needs dedicated model | Needs dedicated model |
| L-STAR | 25 / 18 / ? | 720 | 35 | Needs dedicated model | Needs dedicated model |
| Kraber | 350 / 350 / ? | 111 | 4 | Needs dedicated model | Needs dedicated model |
| Longbow DMR | 55 / 55 / ? | 180 | 6 | Needs dedicated model | Needs dedicated model |
| Double Take | 30 / 30 / ? | 120 | 12 | Needs dedicated model | Needs dedicated model |
| EVA-8 | 200 / 10 / ? | 165 | 6 | Needs dedicated model | Needs dedicated model |
| Mastiff | 20 / 12 / ? | 78 | 4 | Needs dedicated model | Needs dedicated model |
| Mozambique | 30 / 25 / ? | 180 | 6 | Needs dedicated model | Needs dedicated model |
| EPG | 100 / 100 / ? | 60 | 5 | Needs dedicated model | Needs dedicated model |
| Softball | 10 / 10 / ? | 120 | 6 | Needs dedicated model | Needs dedicated model |
| Cold War | 30 / 30 / ? | 720 | 12 | Needs dedicated model | Needs dedicated model |
| SMR | 50 / 50 / ? | 540 | 20 | Needs dedicated model | Needs dedicated model |
| RE-45 | 20 / 13 / 9 | 780 | 20 | 5 hits / 307.7 ms | 8 hits / 538.5 ms |
| P2016 | 30 / 20 / 15 | 480 | 12 | 4 hits / 375.0 ms | 5 hits / 500.0 ms |
| B3 Wingman | 40 / 40 / 30 | 156 | 6 | 3 hits / 769.2 ms | 3 hits / 769.2 ms |
| Wingman Elite | 75 / 55 / 35 | 156 | 6 | Needs dedicated model | Needs dedicated model |
| Charge Rifle | 300 / 300 / ? | 60 | 0 | Needs dedicated model | Needs dedicated model |
| Archer | 100 / 100 / ? | 60 | 1 | Needs dedicated model | Needs dedicated model |
| Thunderbolt | 70 / 70 / ? | 120 | 1 | Needs dedicated model | Needs dedicated model |
| MGL | 20 / 20 / ? | 360 | 6 | Needs dedicated model | Needs dedicated model |

Burst/charge/pellet/ramp/projectile/rechamber weapons need dedicated models. The allowlist is intentionally limited. Current changes to handling and reload do not establish better damage or observed TTK. [Methods and recording](README.md).
