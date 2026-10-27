//! `bot_height_response`: when a visible enemy stays well ABOVE the bot, the
//! bot stops standing in the open below it and moves to a nearby navmesh point
//! that the enemy cannot see, holds briefly, then resumes normal behavior.
//!
//! Played data: 59-81% of bot views of the human on Eden/Meadow had a vertical
//! gap over 180 units, where the range controller deliberately does nothing and
//! the bot walked straight at an unreachable target. Aim and firing are not
//! touched: a bot moving to cover still shoots whenever it can see the target.

#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) enum Intent { None, NeedCover, Cover([f32; 3]) }

#[derive(Debug, Default)]
pub(super) struct HeightResponse {
    above_since: Option<f32>,
    plan: Option<([f32; 3], f32)>,
    fresh: bool,
    cooldown_until: f32,
    last_time: f32,
    pub starts: u32,
    pub no_cover: u32,
}

impl HeightResponse {
    pub const GAP: f32 = 180.;
    pub const CONFIRM: f32 = 1.0;
    pub const HOLD: f32 = 4.0;
    pub const COOLDOWN: f32 = 10.0;
    pub const RETRY: f32 = 3.0;

    fn sane(&mut self, now: f32) -> bool {
        if !now.is_finite() || now < self.last_time {
            let (s, n) = (self.starts, self.no_cover);
            *self = Self { starts: s, no_cover: n, ..Default::default() };
            if !now.is_finite() { return false; }
        }
        self.last_time = now;
        true
    }

    /// Cover point currently being used, if any (for every command, visible or not).
    pub fn active(&mut self, now: f32) -> Option<[f32; 3]> {
        if !self.sane(now) { return None; }
        match self.plan {
            Some((point, until)) if now < until && until - now <= Self::HOLD => Some(point),
            Some(_) => { self.plan = None; None }
            None => None,
        }
    }

    /// True once after a new plan starts, so the route is recalculated once.
    pub fn take_fresh(&mut self) -> bool { std::mem::take(&mut self.fresh) }

    /// `gap` = target height minus bot height (positive: target above).
    pub fn update(&mut self, now: f32, visible: bool, gap: f32) -> Intent {
        if let Some(point) = self.active(now) { return Intent::Cover(point); }
        if !now.is_finite() { return Intent::None; }
        if !(visible && gap.is_finite() && gap > Self::GAP) { self.above_since = None; return Intent::None; }
        let since = *self.above_since.get_or_insert(now);
        if now - since >= Self::CONFIRM && now >= self.cooldown_until { Intent::NeedCover } else { Intent::None }
    }

    pub fn start(&mut self, now: f32, point: [f32; 3]) {
        if !now.is_finite() || !point.iter().all(|v| v.is_finite()) { return; }
        self.plan = Some((point, now + Self::HOLD));
        self.fresh = true;
        self.cooldown_until = now + Self::COOLDOWN;
        self.above_since = None;
        self.starts = self.starts.saturating_add(1);
    }

    pub fn none_found(&mut self, now: f32) {
        if !now.is_finite() { return; }
        self.cooldown_until = now + Self::RETRY;
        self.above_since = None;
        self.no_cover = self.no_cover.saturating_add(1);
    }

    pub fn cancel(&mut self) { self.plan = None; self.above_since = None; self.fresh = false; }
}

/// Candidate filter: same floor as the bot, not on top of it, not too far.
pub(super) fn candidate_ok(bot: [f32; 3], point: [f32; 3]) -> bool {
    if !bot.iter().chain(point.iter()).all(|v| v.is_finite()) { return false; }
    let d = (point[0] - bot[0]).hypot(point[1] - bot[1]);
    (point[2] - bot[2]).abs() < 120. && (100. ..=600.).contains(&d)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn sustained_overhead_target_requests_cover_once_confirmed() {
        let mut h = HeightResponse::default();
        assert_eq!(h.update(0., true, 300.), Intent::None);
        assert_eq!(h.update(0.9, true, 300.), Intent::None);
        assert_eq!(h.update(1.0, true, 300.), Intent::NeedCover);
    }
    #[test] fn level_below_or_hidden_targets_do_not_trigger() {
        for (visible, gap) in [(true, 100.), (true, -400.), (false, 400.), (true, f32::NAN)] {
            let mut h = HeightResponse::default();
            for n in 0..40 { assert_eq!(h.update(n as f32 * 0.1, visible, gap), Intent::None); }
        }
        let mut h = HeightResponse::default();
        h.update(0., true, 300.); h.update(0.8, true, 50.);
        assert_eq!(h.update(1.2, true, 300.), Intent::None); // interruption restarts confirmation
    }
    #[test] fn plan_holds_even_without_sight_then_expires_with_cooldown() {
        let mut h = HeightResponse::default();
        h.update(0., true, 300.); assert_eq!(h.update(1., true, 300.), Intent::NeedCover);
        h.start(1., [10., 0., 0.]);
        assert!(h.take_fresh()); assert!(!h.take_fresh());
        assert_eq!(h.update(2., false, 0.), Intent::Cover([10., 0., 0.]));
        assert_eq!(h.active(4.9), Some([10., 0., 0.]));
        assert_eq!(h.update(5.0, true, 300.), Intent::None);
        assert_eq!(h.update(8.0, true, 300.), Intent::None); // cooldown until 11
        assert_eq!(h.update(11.0, true, 300.), Intent::NeedCover);
        assert_eq!(h.starts, 1);
    }
    #[test] fn no_cover_retries_later_and_clock_reset_clears_plan() {
        let mut h = HeightResponse::default();
        h.update(0., true, 300.); h.update(1., true, 300.); h.none_found(1.);
        assert_eq!(h.update(2., true, 300.), Intent::None);
        assert_eq!(h.update(4., true, 300.), Intent::NeedCover);
        h.start(4., [1., 1., 1.]); assert!(h.active(4.5).is_some());
        assert_eq!(h.active(0.1), None); assert_eq!((h.starts, h.no_cover), (1, 1));
    }
    #[test] fn candidates_stay_on_the_bots_floor_and_nearby() {
        assert!(candidate_ok([0., 0., 0.], [300., 0., 30.]));
        assert!(!candidate_ok([0., 0., 0.], [300., 0., 200.]));
        assert!(!candidate_ok([0., 0., 0.], [50., 0., 0.]));
        assert!(!candidate_ok([0., 0., 0.], [900., 0., 0.]));
        assert!(!candidate_ok([0., 0., f32::NAN], [300., 0., 0.]));
    }
}
