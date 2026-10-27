//! `bot_route_guard` and `bot_jump_timing`: bounded fixes for routing loops.
//!
//! - Partial routes that have been fully consumed are not re-requested every
//!   frame; the old code replanned to the same unreachable end point each tick.
//! - A pursuit target whose routes stay partial and far from it is skipped for
//!   pursuit (never for a visible engagement) for a few seconds.
//! - Step jumps only fire near the higher waypoint, and an airborne bot may add
//!   one second press (double jump) when the waypoint is still well above it.

#[derive(Debug, Default)]
pub(super) struct ReplanThrottle {
    last_plan: Option<f32>,
    last_partial: bool,
}

impl ReplanThrottle {
    pub const PARTIAL_INTERVAL: f32 = 0.5;
    pub fn note_plan(&mut self, now: f32, partial: bool) {
        self.last_plan = now.is_finite().then_some(now);
        self.last_partial = partial;
    }
    /// Only throttles the "route consumed, replan" case after a partial route.
    /// Target changes and far-moved goals always replan.
    pub fn allow_consumed_replan(&self, now: f32) -> bool {
        match self.last_plan {
            Some(at) if self.last_partial && now >= at => now - at >= Self::PARTIAL_INTERVAL,
            _ => true,
        }
    }
}

#[derive(Debug, Default)]
pub(super) struct Unreachable {
    candidate: Option<(i32, f32)>,
    blocked: Option<(i32, f32)>,
}

impl Unreachable {
    pub const GAP: f32 = 250.;
    pub const CONFIRM: f32 = 3.;
    pub const HOLD: f32 = 6.;
    pub fn note(&mut self, now: f32, target: i32, partial: bool, end_gap: f32) {
        if !now.is_finite() { *self = Self::default(); return; }
        if !(partial && end_gap.is_finite() && end_gap > Self::GAP) {
            if self.candidate.is_some_and(|(id, _)| id == target) { self.candidate = None; }
            return;
        }
        match self.candidate {
            Some((id, since)) if id == target && now >= since => {
                if now - since >= Self::CONFIRM {
                    self.blocked = Some((target, now + Self::HOLD));
                    self.candidate = None;
                }
            }
            _ => self.candidate = Some((target, now)),
        }
    }
    pub fn blocks(&self, now: f32, target: i32) -> bool {
        self.blocked.is_some_and(|(id, until)| id == target && now.is_finite()
            && now < until && until - now <= Self::HOLD)
    }
}

/// Step jumps used to fire whenever the next point was 18+ units higher, even
/// 400 units away, so the bot hopped early and arrived at the ledge grounded.
pub(super) fn step_jump_wanted(dz: f32, horizontal: f32) -> bool {
    dz.is_finite() && horizontal.is_finite() && dz > 18. && horizontal < 140.
}

#[derive(Debug, Default)]
pub(super) struct JumpTiming {
    airborne_since: Option<f32>,
    doubled: bool,
    press_until: f32,
}

impl JumpTiming {
    /// Returns true while a bounded second press should be held.
    pub fn double_jump(&mut self, now: f32, grounded: bool, dz_remaining: f32, horizontal: f32) -> bool {
        if !now.is_finite() || grounded {
            self.airborne_since = None;
            self.doubled = false;
            self.press_until = 0.;
            return false;
        }
        let since = *self.airborne_since.get_or_insert(now);
        if now < since { self.airborne_since = Some(now); return false; }
        if now < self.press_until { return true; }
        if !self.doubled && now - since >= 0.2 && dz_remaining.is_finite() && dz_remaining > 40.
            && horizontal.is_finite() && horizontal < 220. {
            self.doubled = true;
            self.press_until = now + 0.06;
            return true;
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn consumed_partial_route_is_not_replanned_every_frame() {
        let mut t = ReplanThrottle::default();
        assert!(t.allow_consumed_replan(1.));
        t.note_plan(1., true);
        assert!(!t.allow_consumed_replan(1.016)); assert!(!t.allow_consumed_replan(1.4));
        assert!(t.allow_consumed_replan(1.5));
        t.note_plan(2., false); assert!(t.allow_consumed_replan(2.01));
        t.note_plan(5., true); assert!(t.allow_consumed_replan(1.)); // clock reset
    }
    #[test] fn unreachable_needs_sustained_far_partial_routes_and_expires() {
        let mut u = Unreachable::default();
        u.note(0., 7, true, 400.); u.note(2., 7, true, 400.); assert!(!u.blocks(2., 7));
        u.note(3., 7, true, 400.); assert!(u.blocks(3.1, 7)); assert!(!u.blocks(3.1, 8));
        assert!(!u.blocks(9.1, 7));
        let mut u = Unreachable::default();
        u.note(0., 7, true, 400.); u.note(1., 7, false, 400.); u.note(3.5, 7, true, 400.);
        assert!(!u.blocks(3.6, 7)); // a complete route reset confirmation
        let mut u = Unreachable::default();
        u.note(0., 7, true, 100.); u.note(5., 7, true, 100.); assert!(!u.blocks(5., 7));
        u.note(0., 7, true, 400.); u.note(4., 7, true, 400.); assert!(!u.blocks(-1., 7));
    }
    #[test] fn step_jump_waits_until_near_the_higher_point() {
        assert!(!step_jump_wanted(22., 400.)); assert!(step_jump_wanted(22., 100.));
        assert!(!step_jump_wanted(10., 50.)); assert!(!step_jump_wanted(f32::NAN, 50.));
    }
    #[test] fn double_jump_is_single_bounded_and_resets_on_landing() {
        let mut j = JumpTiming::default();
        assert!(!j.double_jump(0., false, 80., 100.));
        assert!(!j.double_jump(0.1, false, 80., 100.));
        assert!(j.double_jump(0.2, false, 80., 100.));
        assert!(j.double_jump(0.25, false, 80., 100.));
        assert!(!j.double_jump(0.3, false, 80., 100.));
        assert!(!j.double_jump(0.6, false, 80., 100.));
        assert!(!j.double_jump(0.7, true, 80., 100.));
        assert!(!j.double_jump(0.8, false, 20., 100.)); assert!(!j.double_jump(1.1, false, 20., 100.));
    }
}
