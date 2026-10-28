//! Bounded ownership of a throw: preserve its aim through release, avoid
//! running toward a frag during its fuse, and never queue another throw.
#[derive(Debug, Default)]
pub(super) struct ThrowSafety {
    started: Option<f32>,
    angles: [f32; 2],
    frag: bool,
    checked: Option<(f32, [f32; 3], [f32; 2], bool)>,
}
impl ThrowSafety {
    pub fn start(&mut self, now: f32, angles: [f32; 2], frag: bool) {
        if now.is_finite() && angles.iter().all(|x| x.is_finite()) {
            self.started = Some(now); self.angles = angles; self.frag = frag;
        }
    }
    fn age(&self, now: f32) -> Option<f32> {
        self.started.filter(|at| now.is_finite() && now >= *at).map(|at| now - at)
    }
    pub fn allow_request(&self, now: f32) -> bool {
        self.age(now).is_none_or(|age| age < 0.12 || age >= 3.)
    }
    pub fn aim(&self, now: f32) -> Option<[f32; 2]> {
        self.age(now).filter(|age| *age < 0.85).map(|_| self.angles)
    }
    pub fn brake_forward(&self, now: f32) -> bool {
        self.frag && self.age(now).is_some_and(|age| age < 3.)
    }
    /// A small bounded ray budget; moved/turned throws invalidate the cache.
    pub fn clearance(&mut self, now: f32, origin: [f32; 3], aim: [f32; 2], check: impl FnOnce() -> bool) -> bool {
        if !now.is_finite() || !origin.iter().chain(aim.iter()).all(|v| v.is_finite()) { return false; }
        if let Some((at, p, a, clear)) = self.checked
            && now >= at && now - at < 0.2
            && (0..3).map(|i| (p[i]-origin[i]).powi(2)).sum::<f32>() < 32.*32.
            && (a[0]-aim[0]).abs() < 10. && (a[1]-aim[1]).abs() < 10. { return clear; }
        let clear = check(); self.checked = Some((now, origin, aim, clear)); clear
    }
}

pub(super) fn minimum_range(weapon: &str) -> f32 {
    if weapon == "mp_weapon_frag_grenade" { 550. } else { 250. }
}

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn commit_releases_but_does_not_rearm_or_lose_aim_during_windup() {
        let mut s = ThrowSafety::default(); s.start(10., [-15., 90.], true);
        assert!(s.allow_request(10.05)); assert!(!s.allow_request(10.13));
        assert_eq!(s.aim(10.8), Some([-15.,90.])); assert_eq!(s.aim(10.9), None);
        assert!(s.brake_forward(12.9)); assert!(!s.brake_forward(13.)); assert!(s.allow_request(13.));
        assert_eq!(s.aim(1.), None); assert!(!s.brake_forward(1.)); assert!(s.allow_request(1.));
    }
    #[test] fn nonfrag_does_not_apply_the_frag_movement_brake() {
        let mut s = ThrowSafety::default(); s.start(1., [0.;2], false);
        assert!(!s.brake_forward(1.1)); assert!(s.aim(1.1).is_some());
        assert_eq!(minimum_range("mp_weapon_frag_grenade"), 550.);
        assert_eq!(minimum_range("mp_weapon_grenade_emp"), 250.);
    }
    #[test] fn clearance_cache_is_bounded_and_invalidates_motion_turn_and_clock_reset() {
        let mut s = ThrowSafety::default();
        assert!(!s.clearance(1., [0.;3], [0.;2], || false));
        assert!(!s.clearance(1.1, [0.;3], [0.;2], || panic!("cached")));
        assert!(s.clearance(1.21, [0.;3], [0.;2], || true));
        assert!(!s.clearance(1.22, [33.,0.,0.], [0.;2], || false));
        assert!(s.clearance(1.23, [33.,0.,0.], [0.,11.], || true));
        assert!(!s.clearance(0., [33.,0.,0.], [0.,11.], || false));
        assert!(!s.clearance(f32::NAN, [0.;3], [0.;2], || panic!("invalid")));
    }
}
