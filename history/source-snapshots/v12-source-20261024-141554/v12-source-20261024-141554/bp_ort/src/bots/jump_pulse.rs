//! A jump press must end even when obstacle recovery runs every frame.
pub(super) fn jump_pulse(
    now: f32,
    last_press: &mut f32,
    remaining: &mut u32,
    requested: bool,
) -> bool {
    if *remaining == 0 && requested && now >= *last_press + 0.6 {
        *last_press = now;
        *remaining = 4;
    }
    let pressed = *remaining != 0;
    *remaining = remaining.saturating_sub(1);
    pressed
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn continuous_obstruction_releases_jump_between_attempts() {
        let mut last = -1.;
        let mut remaining = 0;
        let presses: Vec<_> = (0..60)
            .map(|tick| jump_pulse(tick as f32 / 60., &mut last, &mut remaining, true))
            .collect();
        assert!(presses[..4].iter().all(|v| *v));
        assert!(presses[4..36].iter().all(|v| !*v));
        assert_eq!(presses.iter().filter(|v| **v).count(), 8);
    }

    #[test]
    fn existing_hold_expires_even_after_the_obstacle_disappears() {
        let mut last = -1.;
        let mut remaining = 0;
        assert!(jump_pulse(0., &mut last, &mut remaining, true));
        for tick in 1..4 {
            assert!(jump_pulse(tick as f32 / 60., &mut last, &mut remaining, false));
        }
        assert!(!jump_pulse(0.1, &mut last, &mut remaining, false));
        assert!(!jump_pulse(1., &mut last, &mut remaining, false));
    }
}
