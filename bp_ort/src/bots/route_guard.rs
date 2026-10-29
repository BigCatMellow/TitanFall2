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

/// Per-bot pursuit escape when Detour returned a route but the bot repeatedly
/// could not advance along it. This tracks *distinct watchdog events*, not
/// per-frame movement samples. A visible target is never blocked by this state.
#[derive(Debug, Default)]
pub(super) struct StallTargetCooldown {
    // Fixed-size independent histories: switching enemies must not erase strikes.
    recent: [Option<(i32, f32, u8)>; 4],
    blocked: [Option<(i32, f32)>; 4],
    last_time: Option<f32>,
}
impl StallTargetCooldown {
    pub const WINDOW: f32 = 12.;
    pub const HOLD: f32 = 8.;
    pub const STRIKES: u8 = 2;

    /// A watchdog event, not a per-frame sample.
    /// Returns true only when a *new* cooldown starts.
    pub fn record(&mut self, now: f32, target: i32) -> bool {
        if !now.is_finite() || target == -1 { return false; }
        if self.last_time.is_some_and(|last| now < last) { *self = Self::default(); }
        self.last_time = Some(now);
        if self.blocks(now, target) { return false; }

        let slot = self.recent.iter().position(|entry|
            entry.is_some_and(|(id, _, _)| id == target))
            .or_else(|| self.recent.iter().position(|entry|
                entry.is_none_or(|(_, at, _)| now - at > Self::WINDOW)))
            .unwrap_or_else(|| self.recent.iter().enumerate()
                .min_by(|(_, a), (_, b)| {
                    let ta = a.map_or(f32::NEG_INFINITY, |(_, at, _)| at);
                    let tb = b.map_or(f32::NEG_INFINITY, |(_, at, _)| at);
                    ta.total_cmp(&tb)
                }).map_or(0, |(i, _)| i));

        let strikes = match self.recent[slot] {
            Some((id, at, count)) if id == target && now >= at && now - at <= Self::WINDOW =>
                count.saturating_add(1),
            _ => 1,
        };
        if strikes < Self::STRIKES {
            self.recent[slot] = Some((target, now, strikes));
            return false;
        }
        self.recent[slot] = None;
        let slot = self.blocked.iter().position(|entry|
            entry.is_none_or(|(_, until)| now >= until))
            .unwrap_or_else(|| self.blocked.iter().enumerate()
                .min_by(|(_, a), (_, b)| {
                    let ta = a.map_or(f32::NEG_INFINITY, |(_, until)| until);
                    let tb = b.map_or(f32::NEG_INFINITY, |(_, until)| until);
                    ta.total_cmp(&tb)
                }).map_or(0, |(i, _)| i));
        self.blocked[slot] = Some((target, now + Self::HOLD));
        true
    }

    /// Only pursuit selection consults this; visible combat always wins.
    pub fn blocks(&self, now: f32, target: i32) -> bool {
        self.blocked.iter().any(|entry| entry.is_some_and(|(id, until)|
            now.is_finite() && id == target &&
                now >= until - Self::HOLD && now < until))
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
    #[test] fn repeated_watchdog_events_cool_down_only_that_pursuit_target() {
        let mut state = StallTargetCooldown::default();
        assert!(!state.record(1., 7));
        assert!(!state.blocks(3., 7));
        assert!(state.record(5., 7));
        assert!(state.blocks(5., 7));
        assert!(state.blocks(12.9, 7));
        assert!(!state.blocks(13., 7));
        assert!(!state.blocks(6., 8));
        assert!(!state.record(20., 7));
        assert!(!state.record(21., 8)); // independent target history
        assert!(state.record(22., 7));
        assert!(state.record(23., 8));
    }
    #[test] fn alternating_unreachable_enemies_get_separate_cooldowns() {
        let mut state = StallTargetCooldown::default();
        assert!(!state.record(1., 7));
        assert!(!state.record(1.5, 8));
        assert!(state.record(2., 7));
        assert!(state.record(3., 8));
        assert!(state.blocks(9.9, 7));
        assert!(!state.blocks(10., 7)); // expires eight seconds after second hit
        assert!(state.blocks(10., 8));
        assert!(!state.blocks(11., 8));
        assert!(!state.blocks(8., 9));
        assert!(!state.record(3.5, 8)); // no retrigger while still blocked
    }

    #[test] fn cache_is_bounded_and_evicts_oldest_evidence() {
        let mut state = StallTargetCooldown::default();
        for id in 1..=4 { assert!(!state.record(id as f32, id)); }
        assert!(!state.record(5., 5)); // replaces oldest evidence (target 1)
        assert!(state.record(6., 2)); // target 2 history survives
        assert!(!state.record(7., 1)); // target 1 starts fresh
        assert!(!state.blocks(7., 1));
        assert!(state.blocks(7., 2));
    }

    #[test] fn clock_reset_discards_every_cached_target() {
        let mut state = StallTargetCooldown::default();
        assert!(!state.record(40., 7));
        assert!(state.record(41., 7));
        assert!(!state.record(42., 8));
        assert!(!state.record(1., 7));
        assert!(!state.blocks(1., 7));
        assert!(!state.record(2., 8));
        assert!(state.record(3., 7));
        assert!(!state.blocks(3., 8));
    }
    #[test] fn old_hits_and_clock_rollback_do_not_create_false_cooldowns() {
        let mut state = StallTargetCooldown::default();
        assert!(!state.record(10., 2));
        assert!(!state.record(22.1, 2)); // outside the 12s strike window
        assert!(!state.record(1., 2)); // new map/clock reset
        assert!(!state.blocks(1., 2));
        assert!(state.record(2., 2));
        assert!(!state.blocks(f32::NAN, 2));
        assert!(!state.record(f32::NAN, 2));
        assert!(!state.record(3., -1));
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
