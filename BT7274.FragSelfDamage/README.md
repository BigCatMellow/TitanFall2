# Bot frag self-damage

Local solo rule requested by BT-7274: bot pilots take 25% of their normal
self-inflicted frag damage (75% reduction). Human self-damage, damage to enemies,
friendly-fire rules, Titans, other ordnance, fuse/trajectory, aim and firing
warm-up retain existing behavior. Applies only in non-lobby multiplayer with
ns_auth_allow_insecure enabled, and only when attacker is exactly the victim
and that player has the established bot UID 0. No native plugin rebuild needed.

The damage-source callback runs after class damage rules and before final damage
observers, so the weapon notebook sees the scaled amount rather than a later
health refund. Zero scale can suppress later zero-damage observer callbacks;
normal play uses 0.25, not immunity. Invalid scales fail open to ordinary damage.

Controls:
- bt7274_bot_frag_self_damage 1 (default) / 0 restores ordinary self-damage
- bt7274_bot_frag_self_damage_scale 0.25 (default); 1 ordinary, 0 immunity
- bt7274_bot_frag_self_damage_log 0 (default); 1 emits aggregate before/after

Install mod folder and its versioned enabledmods entry only after the isolated
checks. Do not enable BT7274.FragSelfDamageTest in normal play. Back up current
profile files/saves; rollback never overwrites new progress with old saves.

Validation tool: tools/Test-FragSelfDamage.ps1. This separately marks synthetic
TakeDamage health-delta checks, then observes real combat on Drydock/Glitch,
including respawn and lobby/map transitions. It does not establish live balance
or the self-kill reduction percentage; reduced damage can still kill a hurt bot.
