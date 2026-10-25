//! Waypoint churn is not movement. Check displacement independently of paths.
pub(super) fn has_stalled(now: f32, anchor: &mut Option<(f32, [f32; 2])>, pos: [f32; 2]) -> bool {
    if let Some((last, previous)) = *anchor {
        let delta = [pos[0] - previous[0], pos[1] - previous[1]];
        if now < last || delta[0] * delta[0] + delta[1] * delta[1] >= 80. * 80. {
            *anchor = Some((now, pos));
        } else if now - last >= 3. {
            *anchor = Some((now, pos));
            return true;
        }
    } else {
        *anchor = Some((now, pos));
    }
    false
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn small_oscillations_do_not_hide_a_stalled_bot() {
        let mut anchor = None;
        for tick in 0..30 {
            assert!(!has_stalled(tick as f32 / 10., &mut anchor, [(tick % 2) as f32 * 20., 0.]));
        }
        assert!(has_stalled(3., &mut anchor, [0., 0.]));
        assert!(!has_stalled(3.1, &mut anchor, [0., 0.]));
    }
    #[test]
    fn normal_forward_progress_keeps_the_bot_out_of_recovery() {
        let mut anchor = None;
        for tick in 0..100 {
            assert!(!has_stalled(tick as f32 / 10., &mut anchor, [tick as f32 * 26., 0.]));
        }
    }
    #[test]
    fn a_new_map_clock_does_not_inherit_an_expired_timer() {
        let mut anchor = Some((100., [0., 0.]));
        assert!(!has_stalled(0., &mut anchor, [0., 0.]));
        assert!(has_stalled(3., &mut anchor, [0., 0.]));
    }
}
