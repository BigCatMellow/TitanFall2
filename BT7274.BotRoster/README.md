# BT7274.BotRoster — optional bot loadout balance trial (0.1.0)

**Source candidate, not installed or run.** Both convars default to `0`; with
the add-on enabled and both at 0 nothing changes.

- `bt7274_bot_roster 1`: bots (UID "0") get a primary by team rank:
  R-201, G2, CAR, Flatline, DMR (Longbow), Spitfire, Hemlok, R-97 — stock, no
  attachments. Each team receives the same list, so allies and enemies match.
  Excluded: Kraber, shotguns, Mastiff (one/near-one-shot), EPG/Softball/SMR
  (splash) and L-STAR (heat; native reload logic does not manage it).
- `bt7274_bot_tacticals 1` (skills): each rank also gets a tactical and
  ordnance matched to its gun's personality:

  | Gun | Personality | Tactical | Ordnance |
  |---|---|---|---|
  | R-201 | rifleman | Pulse Blade | Frag |
  | G2 | marksman | Cloak | Electric Smoke |
  | CAR | rusher | Stim | Frag |
  | Flatline | rifleman | Holo Pilot | Arc Grenade |
  | DMR | marksman | Cloak | Gravity Star |
  | Spitfire | anchor | A-Wall | Frag |
  | Hemlok | rifleman | Phase Shift | Firestar |
  | R-97 | rusher | Stim | Arc Grenade |

  The suit that grants each tactical is learned from the game (probing untried
  suits at most once per map), not assumed. Use with native `bot_skill_use 1`,
  which decides when each one is worth using.

The human player, damage, fire rate, aim (0.78), the firing warm-up, team
sizes and saves are untouched. Bot weapon behavior comes from the existing
per-weapon combat profiles; Stim/Phase use is the native controller's
(`bot_skill_use 1` adds situational rules for every listed skill).

`BOT_ROSTER` log lines record each assignment and the resulting tactical class;
`BOT_ROSTER_ERROR` disables the add-on after 3 errors. Protocol, target and
rollback: research/bot-balance-20261027/README.md.
