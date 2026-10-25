#[path = "../Notes/candidates/observation-v17-20261025/before/bots/combat_decisions.rs"]
mod v16;
#[path = "../bp_ort/src/bots/combat_decisions.rs"]
mod candidate;

fn next(seed: &mut u32) -> u32 {
    *seed = seed.wrapping_mul(1664525).wrapping_add(1013904223);
    *seed
}

fn main() {
    let mut a = v16::CombatState::default();
    let mut b = candidate::CombatState::default();
    let weapons = ["mp_weapon_rspn101", "mp_weapon_car", "mp_weapon_sniper",
        "mp_weapon_shotgun", "mp_weapon_lstar", "mp_weapon_epg", "unknown"];
    let mut seed = 0x27102026;
    let mut now = 0.0;
    let mut evaluated = 0;
    for step in 0..50_000 {
        now += 0.016;
        if step % 8192 == 0 { now = 0.0; }
        b.begin_command();
        // Exercise bypassed commands as well as decisions, including a
        // paused clock that does not advance between consecutive commands.
        if step % 17 == 0 {
            assert!(!b.updated_this_frame(now));
            continue;
        }
        if step % 23 == 0 { now -= 0.016; }
        let weapon = weapons[next(&mut seed) as usize % weapons.len()];
        let weapon_id = (next(&mut seed) % 4) as i32;
        let clip = (next(&mut seed) % 34) as i32 - 1;
        let visible = next(&mut seed) % 3 != 0;
        let reloading = next(&mut seed) % 5 == 0;
        let distance = if step % 67 == 0 { f32::NAN } else { (next(&mut seed) % 2000) as f32 };
        let height = (next(&mut seed) % 600) as f32 - 300.;
        let slot = (next(&mut seed) % 16) as u16;
        let da = a.decide(v16::Input {now, weapon_id, weapon, clip, reloading, visible, distance, height, slot});
        let db = b.decide(candidate::Input {now, weapon_id, weapon, clip, reloading, visible, distance, height, slot});
        assert_eq!((da.forward, da.side, da.reload, da.suppress_fire),
            (db.forward, db.side, db.reload, db.suppress_fire), "decision at command {step}");
        assert_eq!((&a.weapon, a.clip, a.reloading, a.tactic, a.reload_requests, a.holds, a.retreats, a.blocked_steps),
            (&b.weapon, b.clip, b.reloading, b.tactic, b.reload_requests, b.holds, b.retreats, b.blocked_steps),
            "combat state at command {step}");
        evaluated += 1;
    }
    println!("PASS: {evaluated} evaluated combat decisions across 50000 commands match v16; skipped commands mark cached readings inactive.");
}
