//! `bot_crouch_recovery`: replaces the PR #5 probe-every-0.2s approach.
//!
//! The attempt is stall-triggered, so it never fights sprint/slide momentum:
//! a grounded route-following pilot that is commanding forward movement but has
//! been nearly stationary for 0.4 s tests the route direction with the player's
//! ACTUAL stand and duck hulls (read from the player, not guessed) using a
//! player-collision mask. Only "standing blocked, ducked clear" starts a crouch.
//! Failed spots are remembered per bot so the same obstacle is not retried in a
//! loop, and failure releases control to the existing watchdog/recovery.

#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) enum Fit { StandClear, DuckOnly, Blocked, Unknown }

#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) enum Intent { Normal, Test, Crouch, Failed }

#[derive(Debug, Default)]
pub(super) struct CrouchRecovery {
    slow_since: Option<f32>,
    active: Option<Active>,
    failed: Vec<([f32; 2], f32)>,
    last_time: f32,
    pub attempts: u32,
    pub successes: u32,
    pub failures: u32,
}

#[derive(Clone, Copy, Debug)]
struct Active { start: f32, anchor: [f32; 2], progress_at: f32, origin: [f32; 2], next_check: f32 }

fn dist(a: [f32; 2], b: [f32; 2]) -> f32 { (a[0] - b[0]).hypot(a[1] - b[1]) }

/// Plausibility of hull fields read through engine memory. If the layout were
/// wrong these would be garbage; then the feature stays inert.
pub(super) fn hulls_plausible(stand: ([f32; 3], [f32; 3]), duck: ([f32; 3], [f32; 3])) -> bool {
    let ok = |(min, max): ([f32; 3], [f32; 3])| min.iter().chain(max.iter()).all(|v| v.is_finite())
        && (-64. ..=-4.).contains(&min[0]) && (-64. ..=-4.).contains(&min[1]) && (-8. ..=8.).contains(&min[2])
        && (4. ..=64.).contains(&max[0]) && (4. ..=64.).contains(&max[1]) && (16. ..=128.).contains(&max[2])
        && min[2] + 18. < max[2];
    ok(stand) && ok(duck) && duck.1[2] + 4. < stand.1[2]
}

impl CrouchRecovery {
    pub const SLOW_SPEED: f32 = 50.;
    pub const TRIGGER_AFTER: f32 = 0.4;
    pub const MAX_DURATION: f32 = 3.;
    pub const FAIL_MEMORY: f32 = 20.;
    pub const FAIL_RADIUS: f32 = 96.;

    pub fn is_active(&self) -> bool { self.active.is_some() }

    pub fn cancel(&mut self) { self.active = None; self.slow_since = None; }

    fn remembered_failure(&mut self, now: f32, pos: [f32; 2]) -> bool {
        self.failed.retain(|(_, until)| now < *until && *until - now <= Self::FAIL_MEMORY);
        self.failed.iter().any(|(p, _)| dist(*p, pos) < Self::FAIL_RADIUS)
    }

    /// One call per eligible command. `fit` is evaluated lazily and only when a
    /// test is due, so tracing happens at stalls rather than continuously.
    pub fn update(&mut self, now: f32, pos: [f32; 2], grounded: bool, speed: f32,
        commanding_forward: bool, mut fit: impl FnMut() -> Fit) -> Intent {
        if !now.is_finite() || now < self.last_time {
            let (a, s, f) = (self.attempts, self.successes, self.failures);
            *self = Self { attempts: a, successes: s, failures: f, ..Default::default() };
        }
        self.last_time = now;
        if !pos.iter().all(|v| v.is_finite()) || !speed.is_finite() { self.cancel(); return Intent::Normal; }

        if let Some(mut a) = self.active {
            if !commanding_forward { self.active = None; return Intent::Normal; }
            if dist(pos, a.anchor) >= 8. { a.anchor = pos; a.progress_at = now; }
            let stalled = now - a.progress_at >= 0.6;
            if stalled || now - a.start >= Self::MAX_DURATION {
                self.active = None;
                self.failures = self.failures.saturating_add(1);
                self.failed.push((a.origin, now + Self::FAIL_MEMORY));
                return Intent::Failed;
            }
            if grounded && now >= a.next_check {
                a.next_check = now + 0.2;
                if fit() == Fit::StandClear && dist(pos, a.origin) >= 24. {
                    self.active = None;
                    self.successes = self.successes.saturating_add(1);
                    return Intent::Normal;
                }
            }
            self.active = Some(a);
            return Intent::Crouch;
        }

        if !(grounded && commanding_forward && speed < Self::SLOW_SPEED) {
            self.slow_since = None;
            return Intent::Normal;
        }
        let since = *self.slow_since.get_or_insert(now);
        if now - since < Self::TRIGGER_AFTER || self.remembered_failure(now, pos) { return Intent::Normal; }
        self.slow_since = None; // one test per slow episode
        match fit() {
            Fit::DuckOnly => {
                self.attempts = self.attempts.saturating_add(1);
                self.active = Some(Active { start: now, anchor: pos, progress_at: now, origin: pos, next_check: now + 0.2 });
                Intent::Crouch
            }
            _ => Intent::Test,
        }
    }
}

/// Classify two swept hull traces (fraction, start_solid) toward the route.
pub(super) fn classify(stand: Option<(f32, bool)>, duck: Option<(f32, bool)>) -> Fit {
    let clear = |t: Option<(f32, bool)>| t.and_then(|(f, solid)|
        (f.is_finite() && (0. ..=1.).contains(&f)).then_some(!solid && f >= 0.999));
    match (clear(stand), clear(duck)) {
        (Some(true), _) => Fit::StandClear,
        (Some(false), Some(true)) => Fit::DuckOnly,
        (Some(false), Some(false)) => Fit::Blocked,
        _ => Fit::Unknown,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    const HULLS: (([f32;3],[f32;3]),([f32;3],[f32;3])) =
        (([-16.,-16.,0.],[16.,16.,72.]), ([-16.,-16.,0.],[16.,16.,47.]));
    #[test] fn classify_requires_clean_sweeps() {
        assert_eq!(classify(Some((1., false)), Some((1., false))), Fit::StandClear);
        assert_eq!(classify(Some((0.3, false)), Some((1., false))), Fit::DuckOnly);
        assert_eq!(classify(Some((0.3, false)), Some((0.5, false))), Fit::Blocked);
        assert_eq!(classify(Some((1., true)), Some((1., false))), Fit::DuckOnly);
        assert_eq!(classify(None, Some((1., false))), Fit::Unknown);
        for fraction in [-1., 1.1, f32::INFINITY, f32::NAN] {
            assert_eq!(classify(Some((fraction, false)), Some((1., false))), Fit::Unknown);
            assert_eq!(classify(Some((0.3, false)), Some((fraction, false))), Fit::Unknown);
        }
        assert_eq!(classify(Some((f32::NAN, false)), Some((1., false))), Fit::Unknown);
    }
    #[test] fn hull_plausibility_rejects_garbage_layouts() {
        assert!(hulls_plausible(HULLS.0, HULLS.1));
        assert!(!hulls_plausible(HULLS.0, HULLS.0));
        assert!(!hulls_plausible(HULLS.0, ([-16.,-16.,0.],[16.,16.,16.])));
        assert!(!hulls_plausible(([0.;3],[0.;3]), HULLS.1));
        assert!(!hulls_plausible(HULLS.0, ([-16.,-16.,0.],[16.,16.,f32::NAN])));
    }
    #[test] fn fast_movement_never_triggers_a_test() {
        let mut c = CrouchRecovery::default(); let mut tests = 0;
        for n in 0..200 { let t = n as f32 / 60.;
            assert_eq!(c.update(t, [t * 400., 0.], true, 400., true, || { tests += 1; Fit::DuckOnly }), Intent::Normal); }
        assert_eq!(tests, 0);
    }
    #[test] fn stall_tests_once_then_crouches_through_and_releases() {
        let mut c = CrouchRecovery::default();
        for n in 0..24 { assert_eq!(c.update(n as f32 / 60., [0.;2], true, 5., true, || Fit::DuckOnly), Intent::Normal); }
        assert_eq!(c.update(0.4, [0.;2], true, 5., true, || Fit::DuckOnly), Intent::Crouch);
        let mut last = Intent::Crouch; let mut t = 0.4;
        for n in 1..120 { t = 0.4 + n as f32 / 60.; let x = n as f32 * 1.5;
            last = c.update(t, [x, 0.], true, 90., true, || if x > 60. { Fit::StandClear } else { Fit::DuckOnly });
            if last == Intent::Normal { break; } }
        assert_eq!(last, Intent::Normal); assert!(t < 1.6);
        assert_eq!((c.attempts, c.successes, c.failures), (1, 1, 0));
    }
    #[test] fn blocked_or_open_stall_does_not_crouch_and_tests_once_per_episode() {
        for fit in [Fit::Blocked, Fit::StandClear, Fit::Unknown] {
            let mut c = CrouchRecovery::default(); let mut tests = 0;
            for n in 0..120 { c.update(n as f32 / 60., [0.;2], true, 5., true, || { tests += 1; fit }); }
            assert!(tests >= 1 && tests <= 5, "{tests}");
            assert_eq!(c.attempts, 0);
        }
    }
    #[test] fn no_progress_fails_and_is_remembered() {
        let mut c = CrouchRecovery::default();
        for n in 0..=24 { c.update(n as f32 / 60., [0.;2], true, 5., true, || Fit::DuckOnly); }
        let mut failed_at = None;
        for n in 25..120 { if c.update(n as f32 / 60., [0.;2], true, 5., true, || Fit::DuckOnly) == Intent::Failed { failed_at = Some(n); break; } }
        assert!(failed_at.is_some()); assert_eq!(c.failures, 1);
        let mut tests = 0;
        for n in 0..600 { c.update(3. + n as f32 / 60., [30., 0.], true, 5., true, || { tests += 1; Fit::DuckOnly }); }
        assert_eq!(tests, 0, "failed spot must not be retested for the memory period");
        assert_eq!(c.attempts, 1);
    }
    #[test] fn long_passage_is_bounded_and_stopping_input_cancels() {
        let mut c = CrouchRecovery::default();
        for n in 0..=24 { c.update(n as f32 / 60., [0.;2], true, 5., true, || Fit::DuckOnly); }
        let mut out = Intent::Crouch;
        for n in 1..400 { out = c.update(0.4 + n as f32 / 60., [n as f32, 0.], true, 60., true, || Fit::DuckOnly); if out != Intent::Crouch { break; } }
        assert_eq!(out, Intent::Failed);
        let mut c = CrouchRecovery::default();
        for n in 0..=24 { c.update(n as f32 / 60., [0.;2], true, 5., true, || Fit::DuckOnly); }
        assert_eq!(c.update(0.5, [0.;2], true, 5., false, || Fit::DuckOnly), Intent::Normal);
        assert!(!c.is_active());
    }
    #[test] fn clock_rollback_clears_attempt_but_keeps_counters() {
        let mut c = CrouchRecovery::default();
        for n in 0..=24 { c.update(100. + n as f32 / 60., [0.;2], true, 5., true, || Fit::DuckOnly); }
        assert!(c.is_active());
        assert_eq!(c.update(1., [0.;2], true, 200., true, || Fit::DuckOnly), Intent::Normal);
        assert!(!c.is_active()); assert_eq!(c.attempts, 1);
    }
}
