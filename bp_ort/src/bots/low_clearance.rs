//! Opt-in, bounded crouch intent. Probe rays are hints, never hull-clearance proof.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) enum Clearance { Open, CrouchCandidate, Blocked }
#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) enum Intent { Normal, Crouch, Recover }
#[derive(Debug, Default)]
pub(super) struct LowClearance {
    next_probe: f32,
    sample: Option<(f32, [f32; 2], f32, Clearance)>,
    active: Option<(f32, f32, [f32; 2])>,
    retry_at: f32,
    last: Option<f32>,
    pub attempts: u32,
    pub failures: u32,
}
impl LowClearance {
    pub fn reset(&mut self) {
        let (attempts, failures) = (self.attempts, self.failures);
        *self = Self { attempts, failures, ..Self::default() };
    }
    pub fn cancel(&mut self) {
        // Interruptions must not turn a bounded attempt into repeated new starts.
        if let Some((start, _, _)) = self.active { self.retry_at = self.retry_at.max(start + 6.); }
        self.active = None;
        self.sample = None;
    }
    pub fn probe_due(&mut self, now: f32) -> bool {
        if !now.is_finite() { self.reset(); return false; }
        if self.last.is_some_and(|last| now < last) { self.reset(); }
        self.last = Some(now);
        if now < self.next_probe { return false; }
        self.next_probe = now + 0.2;
        true
    }
    pub fn observe(&mut self, now: f32, pos: [f32; 2], yaw: f32, clearance: Clearance) {
        self.sample = Some((now, pos, yaw, clearance));
    }
    fn abort(&mut self, now: f32) -> Intent {
        self.active = None;
        self.retry_at = now + 4.;
        self.failures = self.failures.saturating_add(1);
        Intent::Recover
    }
    pub fn decide(&mut self, now: f32, pos: [f32; 2], yaw: f32, grounded: bool) -> Intent {
        if !grounded || !now.is_finite() || !yaw.is_finite() || !pos.iter().all(|v| v.is_finite()) {
            self.cancel();
            return Intent::Normal;
        }
        let Some((at, point, facing, clearance)) = self.sample else { return Intent::Normal; };
        let turn = ((yaw - facing + 180.).rem_euclid(360.) - 180.).abs();
        if now < at || now - at > 0.25 || distance(pos, point) > 48. || turn > 25. {
            if self.active.is_some() { return self.abort(now); }
            return Intent::Normal;
        }
        if let Some((start, progress_at, anchor)) = self.active {
            if clearance == Clearance::Blocked || now - start >= 2.
                || (now - progress_at >= 0.6 && distance(pos, anchor) < 8.) {
                return self.abort(now);
            }
            if clearance == Clearance::Open { self.active = None; return Intent::Normal; }
            if distance(pos, anchor) >= 8. { self.active = Some((start, now, pos)); }
            return Intent::Crouch;
        }
        if clearance == Clearance::CrouchCandidate && now >= self.retry_at {
            self.active = Some((now, now, pos));
            self.attempts = self.attempts.saturating_add(1);
            return Intent::Crouch;
        }
        Intent::Normal
    }
}
fn distance(a: [f32; 2], b: [f32; 2]) -> f32 { (a[0]-b[0]).hypot(a[1]-b[1]) }

// Heights/width are conservative trial probes, not verified player hull dimensions.
pub(super) fn classify(upper: f32, lower: &[f32], floor: &[f32]) -> Clearance {
    if !upper.is_finite() || lower.len() != 6 || floor.len() != 3
        || !lower.iter().all(|v| v.is_finite() && *v >= 0.98 && *v <= 1.)
        || !floor.iter().all(|v| v.is_finite() && *v > 0.01 && *v < 0.95) {
        return Clearance::Blocked;
    }
    if upper < 0.98 && upper >= 0. { Clearance::CrouchCandidate }
    else if upper <= 1. && upper >= 0.98 { Clearance::Open }
    else { Clearance::Blocked }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn sample(s: &mut LowClearance, t: f32, p: [f32;2], c: Clearance) {
        s.probe_due(t); s.observe(t,p,0.,c);
    }
    #[test] fn wall_edge_unknown_and_clear_lane_do_not_request_crouch() {
        assert_eq!(classify(0.4,&[1.;6],&[0.5;3]),Clearance::CrouchCandidate);
        assert_eq!(classify(1.,&[1.;6],&[0.5;3]),Clearance::Open);
        for lower in [[0.5;6],[f32::NAN;6]] { assert_eq!(classify(0.4,&lower,&[0.5;3]),Clearance::Blocked); }
        for floor in [[1.;3],[0.;3],[f32::NAN;3]] { assert_eq!(classify(0.4,&[1.;6],&floor),Clearance::Blocked); }
        let mut s=LowClearance::default(); sample(&mut s,1.,[0.;2],Clearance::Blocked);
        assert_eq!(s.decide(1.,[0.;2],0.,true),Intent::Normal);
    }
    #[test] fn moving_through_then_clear_releases_duck() {
        let mut s=LowClearance::default(); sample(&mut s,1.,[0.;2],Clearance::CrouchCandidate);
        assert_eq!(s.decide(1.,[0.;2],0.,true),Intent::Crouch);
        sample(&mut s,1.5,[20.,0.],Clearance::CrouchCandidate);
        assert_eq!(s.decide(1.5,[20.,0.],0.,true),Intent::Crouch);
        sample(&mut s,1.7,[30.,0.],Clearance::Open);
        assert_eq!(s.decide(1.7,[30.,0.],0.,true),Intent::Normal);
    }
    #[test] fn no_progress_and_long_passage_recover_with_cooldown() {
        for moving in [false,true] {
            let mut s=LowClearance::default();
            for n in 0..=10 {
                let t=1.+n as f32*0.21; let p=[if moving {n as f32*10.} else {0.},0.];
                sample(&mut s,t,p,Clearance::CrouchCandidate);
                let intent=s.decide(t,p,0.,true);
                if intent==Intent::Recover {
                    assert!(n>=3); assert_eq!(s.failures,1);
                    sample(&mut s,t+0.21,p,Clearance::CrouchCandidate);
                    assert_eq!(s.decide(t+0.21,p,0.,true),Intent::Normal); break;
                }
            }
            assert_eq!(s.failures,1);
        }
    }
    #[test] fn stale_airborne_teleport_and_turn_do_not_reuse_probe() {
        for (t,p,yaw,grounded) in [(1.3,[0.;2],0.,true),(1.,[0.;2],0.,false),
            (1.,[100.,0.],0.,true),(1.,[0.;2],90.,true),(1.,[0.;2],f32::NAN,true)] {
            let mut s=LowClearance::default(); sample(&mut s,1.,[0.;2],Clearance::CrouchCandidate);
            assert_eq!(s.decide(t,p,yaw,grounded),Intent::Normal);
        }
    }
    #[test] fn invalidated_active_probe_aborts_and_context_cancel_keeps_cooldown() {
        for (at,yaw,pos) in [(1.3,0.,[0.;2]),(1.1,90.,[0.;2]),(1.1,0.,[100.,0.])] {
            let mut s=LowClearance::default(); sample(&mut s,1.,[0.;2],Clearance::CrouchCandidate);
            assert_eq!(s.decide(1.,[0.;2],0.,true),Intent::Crouch);
            assert_eq!(s.decide(at,pos,yaw,true),Intent::Recover);
            s.cancel();
            sample(&mut s,at+0.21,[0.;2],Clearance::CrouchCandidate);
            assert_eq!(s.decide(at+0.21,[0.;2],0.,true),Intent::Normal);
            assert_eq!(s.attempts,1);
        }
    }
    #[test] fn interruption_cannot_restart_a_crouch_episode_each_frame() {
        let mut s=LowClearance::default(); sample(&mut s,1.,[0.;2],Clearance::CrouchCandidate);
        assert_eq!(s.decide(1.,[0.;2],0.,true),Intent::Crouch);
        s.cancel();
        for n in 1..20 {
            let t=1.+n as f32*0.21;
            sample(&mut s,t,[0.;2],Clearance::CrouchCandidate);
            assert_eq!(s.decide(t,[0.;2],0.,true),Intent::Normal);
        }
        assert_eq!(s.attempts,1);
    }
    #[test] fn wrapped_heading_is_not_a_large_turn() {
        let mut s=LowClearance::default(); s.probe_due(1.);
        s.observe(1.,[0.;2],179.,Clearance::CrouchCandidate);
        assert_eq!(s.decide(1.,[0.;2],-179.,true),Intent::Crouch);
    }
    #[test] fn probe_budget_clock_reset_and_context_reset() {
        let mut s=LowClearance::default(); assert!(s.probe_due(10.));
        assert!(!s.probe_due(10.01)); assert!(s.probe_due(10.21));
        assert!(s.probe_due(1.)); sample(&mut s,1.,[0.;2],Clearance::CrouchCandidate);
        assert_eq!(s.decide(1.,[0.;2],0.,true),Intent::Crouch);
        s.reset(); assert_eq!(s.decide(1.01,[0.;2],0.,true),Intent::Normal);
        assert!(!s.probe_due(f32::NAN));
    }
}
