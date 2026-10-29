//! Input-edge-only observation for frag grenade investigation.
//! This does NOT observe projectiles, detonation, confirmed casts or damage.
//! Bots are addressed by their local lifecycle state, not persistent IDs.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Edge { Press, Release }
impl Edge {
    pub fn as_str(self) -> &'static str {
        match self { Self::Press => "press", Self::Release => "release" }
    }
}
#[derive(Debug, Default)]
pub(super) struct FragInputProbe {
    last_time: Option<f32>,
    held_since: Option<f32>,
}
impl FragInputProbe {
    pub fn observe(&mut self, now: f32, equipped: bool, pressed: bool) -> Option<(Edge, f32)> {
        if !now.is_finite() {
            *self = Self::default();
            return None;
        }
        if self.last_time.is_some_and(|last| now < last) {
            *self = Self::default();
        }
        self.last_time = Some(now);
        if !equipped {
            self.held_since = None;
            return None;
        }
        if pressed {
            if self.held_since.is_none() {
                self.held_since = Some(now);
                return Some((Edge::Press, 0.));
            }
            None
        } else {
            self.held_since.take().map(|at| (Edge::Release, (now - at).max(0.)))
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn observes_one_edge_per_transition_not_per_frame() {
        let mut p = FragInputProbe::default();
        assert_eq!(p.observe(1., true, false), None);
        assert_eq!(p.observe(1.05, true, true), Some((Edge::Press, 0.)));
        assert_eq!(p.observe(1.10, true, true), None);
        let (edge, held) = p.observe(1.17, true, false).unwrap();
        assert_eq!(edge, Edge::Release);
        assert!((held - 0.12).abs() < 0.001);
        assert_eq!(p.observe(1.18, true, false), None);
        assert_eq!(p.observe(2., true, true), Some((Edge::Press, 0.)));
    }
    #[test] fn invalid_lifecycle_and_equipment_reset_state() {
        let mut p = FragInputProbe::default();
        p.observe(10., true, true);
        assert_eq!(p.observe(10.1, false, false), None);
        assert_eq!(p.observe(10.2, true, false), None);
        assert_eq!(p.observe(11., true, true), Some((Edge::Press, 0.)));
        assert_eq!(p.observe(f32::NAN, true, true), None);
        assert_eq!(p.observe(0., true, false), None);
        assert_eq!(p.observe(0.1, true, true), Some((Edge::Press, 0.)));
        assert_eq!(p.observe(0., true, false), None); // map clock rollback
    }
}
