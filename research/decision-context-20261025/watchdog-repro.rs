//! Research reproduction of current behavior, NOT a proposed gameplay patch.
//! Compile directly with rustc; no engine, game, deployment or network needed.
#[path = "../../bp_ort/src/bots/progress_watchdog.rs"]
mod progress_watchdog;

fn main() {
    let mut anchor = None;
    assert!(!progress_watchdog::has_stalled(0., &mut anchor, [0., 0.]));
    // No path-following calls during four seconds of stationary visible combat.
    let triggers_after_gap = progress_watchdog::has_stalled(4., &mut anchor, [0., 0.]);

    let mut fresh_anchor = None;
    let triggers_with_fresh_anchor = progress_watchdog::has_stalled(4., &mut fresh_anchor, [0., 0.]);
    let mut moving_anchor = Some((0., [0., 0.]));
    let triggers_after_movement = progress_watchdog::has_stalled(4., &mut moving_anchor, [100., 0.]);
    let mut stuck_anchor = None;
    for t in [0., 1., 2.] {
        assert!(!progress_watchdog::has_stalled(t, &mut stuck_anchor, [0., 0.]));
    }
    let triggers_with_real_nav_stall = progress_watchdog::has_stalled(3., &mut stuck_anchor, [0., 0.]);
    println!("{{\"triggers_after_four_second_call_gap\":{triggers_after_gap},\"triggers_with_fresh_anchor\":{triggers_with_fresh_anchor},\"triggers_after_100_units_movement\":{triggers_after_movement},\"triggers_after_three_seconds_continuous_stationary_nav\":{triggers_with_real_nav_stall}}}");
}
