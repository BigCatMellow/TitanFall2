//! Diagnostic-only helpers for `bot_nav_diagnostics`. Nothing here changes input.
//!
//! These answer the open review questions without guessing: which route corners
//! are native traversal links, whether the pathfinder returned a partial route,
//! and where bots stop while commanding movement in ANY state (including engage,
//! which the older low-progress detector excluded).

/// Detour status bits. Success matches the existing check in navigation.rs; the
/// partial bit is the vanilla Detour value and is logged raw so the Titanfall
/// variant can be confirmed from real output before any behavior depends on it.
pub(super) const DT_SUCCESS: u32 = 1 << 30;
pub(super) const DT_PARTIAL_RESULT: u32 = 1 << 6;

pub(super) fn is_partial(status: u32) -> bool {
    status & DT_SUCCESS != 0 && status & DT_PARTIAL_RESULT != 0
}

/// Suppresses repeated identical log lines (e.g. per-frame replanning) while
/// counting what was suppressed so the volume itself remains visible.
#[derive(Debug, Default)]
pub(super) struct RateGate {
    last: Option<f32>,
    pub suppressed: u32,
}

impl RateGate {
    pub fn allow(&mut self, now: f32, interval: f32) -> bool {
        if !now.is_finite() { return false; }
        match self.last {
            Some(last) if now >= last && now - last < interval => {
                self.suppressed = self.suppressed.saturating_add(1);
                false
            }
            _ => { self.last = Some(now); true }
        }
    }
    pub fn take_suppressed(&mut self) -> u32 { std::mem::take(&mut self.suppressed) }
}

/// State-agnostic stuck episodes: grounded, commanding movement, not moving.
#[derive(Debug, Default)]
pub(super) struct StuckMonitor {
    since: Option<f32>,
    reported: bool,
    pub episodes: u32,
}

impl StuckMonitor {
    pub const MIN_DURATION: f32 = 1.5;
    /// Returns the episode age once, when an episode first reaches MIN_DURATION.
    pub fn update(&mut self, now: f32, commanded: bool, grounded: bool, speed: f32) -> Option<f32> {
        if !now.is_finite() || !speed.is_finite() {
            *self = Self { episodes: self.episodes, ..Default::default() };
            return None;
        }
        if self.since.is_some_and(|since| now < since) { self.since = None; self.reported = false; }
        let stuck = commanded && grounded && speed < 30.;
        if !stuck {
            // Brief slowdowns while still pressing do not end an episode; real movement does.
            if !commanded || speed > 60. { self.since = None; self.reported = false; }
            return None;
        }
        let since = *self.since.get_or_insert(now);
        if !self.reported && now - since >= Self::MIN_DURATION {
            self.reported = true;
            self.episodes = self.episodes.saturating_add(1);
            return Some(now - since);
        }
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn partial_requires_success_and_partial_bits() {
        assert!(is_partial(DT_SUCCESS | DT_PARTIAL_RESULT));
        assert!(!is_partial(DT_SUCCESS));
        assert!(!is_partial(DT_PARTIAL_RESULT));
    }
    #[test] fn rate_gate_counts_suppressed_repeats_and_survives_clock_reset() {
        let mut g = RateGate::default();
        assert!(g.allow(1., 1.)); assert!(!g.allow(1.2, 1.)); assert!(!g.allow(1.9, 1.));
        assert_eq!(g.take_suppressed(), 2); assert!(g.allow(2.0, 1.));
        assert!(g.allow(0.5, 1.)); // new map clock
        assert!(!g.allow(f32::NAN, 1.));
    }
    #[test] fn stuck_episode_reports_once_and_ends_on_real_movement() {
        let mut m = StuckMonitor::default();
        assert_eq!(m.update(0., true, true, 5.), None);
        assert_eq!(m.update(1.4, true, true, 5.), None);
        assert!(m.update(1.5, true, true, 5.).is_some());
        assert_eq!(m.update(3., true, true, 5.), None);
        assert_eq!(m.update(3.1, true, true, 40.), None); // slowdown band keeps episode
        assert_eq!(m.update(3.2, true, true, 5.), None);
        m.update(3.3, true, true, 200.);
        m.update(4., true, true, 5.);
        assert!(m.update(5.6, true, true, 5.).is_some());
        assert_eq!(m.episodes, 2);
    }
    #[test] fn airborne_or_idle_is_not_stuck() {
        let mut m = StuckMonitor::default();
        for n in 0..40 { assert_eq!(m.update(n as f32 * 0.1, true, false, 0.), None); }
        for n in 0..40 { assert_eq!(m.update(10. + n as f32 * 0.1, false, true, 0.), None); }
    }
}
