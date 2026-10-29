//! Opt-in early clearance check before a bot reaches a low obstacle.
//! Uses actual hull traces supplied by the caller, not guessed geometry.
//! Never attempts to interpret unknown Detour traversal/jump type values.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Clearance { StandClear, DuckOnly, Unsafe }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Intent { Normal, Duck, Failed }

#[derive(Clone, Copy, Debug)]
struct Active {
    start: f32,
    origin: [f32; 2],
    anchor: [f32; 2],
    progress_at: f32,
    next_check: f32,
}
#[derive(Debug, Default)]
pub(super) struct ClearanceApproach {
    next_probe: f32,
    candidate: Option<([f32; 2], f32)>,
    active: Option<Active>,
    failed: Option<([f32; 2], f32)>,
    last_time: f32,
    pub probes: u32,
    pub starts: u32,
    pub successes: u32,
    pub failures: u32,
}
fn separation(a: [f32; 2], b: [f32; 2]) -> f32 {
    (a[0] - b[0]).hypot(a[1] - b[1])
}
impl ClearanceApproach {
    pub const CHECK_INTERVAL: f32 = 0.2;
    pub const HOLD_LIMIT: f32 = 2.;
    pub const FAIL_MEMORY: f32 = 15.;
    pub fn cancel(&mut self) { self.active = None; self.candidate = None; }
    pub fn is_active(&self) -> bool { self.active.is_some() }
    /// The native straight-path metadata must not announce a special link.
    /// Absence of metadata is unknown, not permission to take over a link.
    pub fn ordinary_corner(meta: Option<(u8, u8)>) -> bool {
        meta.is_some_and(|(flags, jump)| flags & 0x04 == 0
            && jump == 0)
    }
    /// Checks are at most 5Hz, require a grounded pilot actively travelling
    /// along an ordinary route, and never override a running escape recovery.
    pub fn update(&mut self, now: f32, pos: [f32; 2], grounded: bool,
        route: bool, speed: f32, corner_distance: f32,
        ordinary: bool, mut trace: impl FnMut() -> Clearance) -> Intent {
        if !now.is_finite() || now < self.last_time {
            *self = Self::default();
            if !now.is_finite() { return Intent::Normal; }
        }
        self.last_time = now;
        if !pos.iter().all(|v| v.is_finite()) || !speed.is_finite() {
            self.cancel(); return Intent::Normal;
        }
        if !route || !grounded { self.cancel(); return Intent::Normal; }
        if let Some(mut active) = self.active {
            if separation(pos, active.anchor) >= 8. {
                active.anchor = pos; active.progress_at = now;
            }
            if now - active.start >= Self::HOLD_LIMIT || now - active.progress_at >= 0.65 {
                self.active = None;
                self.failures = self.failures.saturating_add(1);
                self.failed = Some((active.origin, now + Self::FAIL_MEMORY));
                return Intent::Failed;
            }
            if now >= active.next_check {
                active.next_check = now + Self::CHECK_INTERVAL;
                self.probes = self.probes.saturating_add(1);
                if trace() == Clearance::StandClear
                    && separation(pos, active.origin) >= 24. {
                    self.active = None;
                    self.successes = self.successes.saturating_add(1);
                    return Intent::Normal;
                }
            }
            self.active = Some(active);
            return Intent::Duck;
        }
        // Do not override ordinary sprint/slide, target holds, or native links.
        if !ordinary || !corner_distance.is_finite()
            || !(55. ..=220.).contains(&corner_distance)
            || !(35. ..=180.).contains(&speed) {
            self.candidate = None;
            return Intent::Normal;
        }
        if self.failed.is_some_and(|(spot, until)| now < until
            && until - now <= Self::FAIL_MEMORY
            && separation(pos, spot) < 96.) {
            return Intent::Normal;
        }
        if now < self.next_probe { return Intent::Normal; }
        self.next_probe = now + Self::CHECK_INTERVAL;
        self.probes = self.probes.saturating_add(1);
        if trace() != Clearance::DuckOnly {
            self.candidate = None;
            return Intent::Normal;
        }
        if self.candidate.is_some_and(|(spot, at)| now >= at
            && now - at <= 0.7 && separation(pos, spot) <= 64.) {
            self.candidate = None;
            self.starts = self.starts.saturating_add(1);
            self.active = Some(Active { start: now, origin: pos, anchor: pos,
                progress_at: now, next_check: now + Self::CHECK_INTERVAL });
            Intent::Duck
        } else {
            self.candidate = Some((pos, now));
            Intent::Normal
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn two_confirmations_then_release_after_standing_clear_and_progress() {
        let mut a = ClearanceApproach::default();
        assert_eq!(a.update(0., [0., 0.], true, true, 80., 100., true,
            || Clearance::DuckOnly), Intent::Normal);
        assert_eq!(a.update(0.21, [5., 0.], true, true, 80., 90., true,
            || Clearance::DuckOnly), Intent::Duck);
        assert_eq!(a.update(0.45, [35., 0.], true, true, 60., 70., true,
            || Clearance::StandClear), Intent::Normal);
        assert_eq!((a.starts, a.successes, a.failures), (1, 1, 0));
    }
    #[test] fn no_native_link_or_fast_route_takeover() {
        assert!(ClearanceApproach::ordinary_corner(Some((0, 0))));
        assert!(!ClearanceApproach::ordinary_corner(None));
        assert!(!ClearanceApproach::ordinary_corner(Some((4, 0))));
        assert!(!ClearanceApproach::ordinary_corner(Some((0, 7))));
        assert!(!ClearanceApproach::ordinary_corner(Some((0, u8::MAX))));
        let mut a = ClearanceApproach::default();
        for n in 0..20 {
            assert_eq!(a.update(n as f32 * 0.25, [0., 0.], true,
                true, 300., 100., true, || panic!("unexpected trace")), Intent::Normal);
        }
        assert_eq!(a.probes, 0);
    }
    #[test] fn stuck_passage_fails_and_does_not_retry_nearby() {
        let mut a = ClearanceApproach::default();
        a.update(0., [0., 0.], true, true, 60., 100., true, || Clearance::DuckOnly);
        assert_eq!(a.update(0.21, [0., 0.], true, true, 60., 100., true,
            || Clearance::DuckOnly), Intent::Duck);
        assert_eq!(a.update(0.9, [0., 0.], true, true, 0., 100., true,
            || panic!("unexpected trace")), Intent::Failed);
        assert_eq!(a.update(1.3, [20., 0.], true, true, 60., 100., true,
            || panic!("should remember failed spot")), Intent::Normal);
        assert_eq!(a.failures, 1);
    }
    #[test] fn interrupted_route_and_map_reset_release_input() {
        let mut a = ClearanceApproach::default();
        a.update(10., [0., 0.], true, true, 60., 100., true, || Clearance::DuckOnly);
        a.update(10.21, [0., 0.], true, true, 60., 100., true, || Clearance::DuckOnly);
        assert!(a.is_active());
        assert_eq!(a.update(10.3, [0., 0.], false, true, 60., 100., true,
            || panic!("invalid trace")), Intent::Normal);
        assert!(!a.is_active());
        assert_eq!(a.update(1., [0., 0.], true, false, 0., 100., true,
            || panic!("invalid trace")), Intent::Normal);
        assert!(!a.is_active());
    }
}
