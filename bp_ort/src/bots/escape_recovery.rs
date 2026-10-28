//! Escalate physical avoidance only; do not change targets or navigation.
#[derive(Debug, Default)]
pub(super) struct EscapeRecovery {
    episode: Option<(f32, [f32; 2], u8)>,
}
impl EscapeRecovery {
    pub fn repeated(&self, now: f32) -> bool {
        self.episode.is_some_and(|(at, _, count)| count >= 3 && now >= at && now - at < 1.2)
    }
    pub fn stalled(&mut self, now: f32, pos: [f32; 2]) {
        let count = self.episode.filter(|(at, previous, _)| now >= *at && now - *at < 12.
            && (pos[0]-previous[0]).hypot(pos[1]-previous[1]) < 192.)
            .map_or(1, |(_, _, n)| n.saturating_add(1));
        self.episode = Some((now, pos, count));
    }
    pub fn backstep_side(&self, now: f32, slot: u16) -> Option<f32> {
        let (at, _, count) = self.episode?;
        if count < 2 || now < at || now - at > 1.2 { return None; }
        Some(if (slot as u32 + count as u32) % 2 == 0 { -0.8 } else { 0.8 })
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn retarget_needs_three_local_stalls_and_never_a_stale_episode() {
        let mut r = EscapeRecovery::default();
        for t in [1., 4.] { r.stalled(t, [0.;2]); assert!(!r.repeated(t)); }
        r.stalled(7., [0.;2]); assert!(r.repeated(7.));
        assert!(!r.repeated(8.3)); assert!(!r.repeated(0.));
        r.stalled(9., [300.,0.]); assert!(!r.repeated(9.));
    }
    #[test]
    fn first_stall_retains_original_avoidance_and_backstep_is_bounded() {
        let mut r = EscapeRecovery::default();
        r.stalled(3., [0.;2]); assert_eq!(r.backstep_side(3., 1), None);
        r.stalled(6., [10.,0.]); assert!(r.backstep_side(6.5, 1).is_some());
        assert_eq!(r.backstep_side(7.3, 1), None);
        assert_eq!(r.backstep_side(1., 1), None);
    }
    #[test]
    fn moving_to_another_location_or_expired_episode_resets_escalation() {
        let mut r = EscapeRecovery::default();
        r.stalled(3., [0.;2]); r.stalled(6., [300.,0.]);
        assert_eq!(r.backstep_side(6., 1), None);
        r.stalled(20., [300.,0.]); assert_eq!(r.backstep_side(20., 1), None);
    }
    #[test]
    fn neighbors_and_subsequent_attempts_do_not_backstep_in_lockstep() {
        let mut r = EscapeRecovery::default();
        r.stalled(3., [0.;2]); r.stalled(6., [0.;2]);
        let side = r.backstep_side(6., 1).unwrap();
        assert_eq!(r.backstep_side(6., 2), Some(-side));
        r.stalled(9., [0.;2]); assert_eq!(r.backstep_side(9., 1), Some(-side));
    }
}
