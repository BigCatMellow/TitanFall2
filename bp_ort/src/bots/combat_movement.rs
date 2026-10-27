//! `bot_combat_movement`: pilot-like movement while engaging. Aim, the firing
//! warm-up and damage are untouched; only the movement vector changes.
//!
//! - Out of weapon range, follow the navmesh route toward the target instead of
//!   walking straight at it (which ignored geometry), while still aiming.
//! - In range, strafe at full magnitude with per-bot pseudo-random reversal
//!   intervals instead of a 0.3-strength, fixed 3.2 s schedule.
//! - A blocked step tries ranked alternatives before standing still, and an
//!   airborne bot keeps its last grounded choice instead of zero input.

/// Converts a move expressed relative to `from_yaw` into one relative to
/// `to_yaw` (Source: +forward along yaw, +side is to the right).
pub(super) fn reframe(fwd: f32, side: f32, from_yaw: f32, to_yaw: f32) -> (f32, f32) {
    if ![fwd, side, from_yaw, to_yaw].iter().all(|v| v.is_finite()) { return (0., 0.); }
    let world = from_yaw.to_radians() + (-side).atan2(fwd);
    let magnitude = fwd.hypot(side).min(1.);
    let rel = world - to_yaw.to_radians();
    let (s, c) = rel.sin_cos();
    (c * magnitude, -s * magnitude)
}

#[derive(Debug, Default)]
pub(super) struct Strafe {
    side: f32,
    next_switch: f32,
    switches: u32,
    last: Option<(f32, f32)>,
    last_time: f32,
}

fn hash(mut x: u32) -> u32 {
    x ^= x >> 16; x = x.wrapping_mul(0x7feb_352d);
    x ^= x >> 15; x = x.wrapping_mul(0x846c_a68b);
    x ^ (x >> 16)
}

impl Strafe {
    pub const MIN_PERIOD: f32 = 0.4;
    pub const MAX_PERIOD: f32 = 1.2;

    /// Current preferred side (+1 right / -1 left); reverses on a per-bot
    /// pseudo-random 0.4-1.2 s schedule that neighbours do not share.
    pub fn side(&mut self, now: f32, slot: u16) -> f32 {
        if !now.is_finite() || now < self.last_time { *self = Self::default(); }
        self.last_time = now;
        if self.side == 0. || now >= self.next_switch {
            self.switches = self.switches.wrapping_add(1);
            let r = hash((slot as u32).wrapping_mul(2_654_435_761) ^ self.switches);
            let frac = (r % 1000) as f32 / 1000.;
            self.side = if self.side == 0. { if r & 1 == 0 { 1. } else { -1. } } else { -self.side };
            self.next_switch = now + Self::MIN_PERIOD + frac * (Self::MAX_PERIOD - Self::MIN_PERIOD);
        }
        self.side
    }
    pub fn remember(&mut self, out: (f32, f32)) { self.last = Some(out); }
    pub fn airborne_output(&self) -> (f32, f32) { self.last.unwrap_or((0., 0.)) }
}

/// Ranked alternatives for a combat step: preferred side, opposite side, then
/// diagonals that keep the requested forward/back intent. Returns the first
/// candidate the (cached, grounded) trace accepts.
pub(super) fn choose_step(forward: f32, side: f32, mut clear: impl FnMut(f32, f32) -> bool) -> Option<(f32, f32)> {
    let f = if forward.is_finite() { forward } else { 0. };
    let s = if side.is_finite() && side != 0. { side.signum() } else { 1. };
    let candidates = [
        (f, s), (f, -s),
        (if f < 0. { f } else { 0.6 }, s * 0.7), (if f < 0. { f } else { 0.6 }, -s * 0.7),
        (-0.6, s * 0.7), (-0.6, -s * 0.7),
    ];
    let mut seen: Vec<(f32, f32)> = Vec::with_capacity(candidates.len());
    for c in candidates {
        if seen.iter().any(|p| (p.0 - c.0).abs() < 1e-3 && (p.1 - c.1).abs() < 1e-3) { continue; }
        seen.push(c);
        if clear(c.0, c.1) { return Some(c); }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    fn close(a: (f32, f32), b: (f32, f32)) -> bool { (a.0 - b.0).abs() < 1e-4 && (a.1 - b.1).abs() < 1e-4 }
    #[test] fn reframe_preserves_world_direction() {
        // Route east (yaw 0) while aiming north (yaw 90): east is to the right.
        assert!(close(reframe(1., 0., 0., 90.), (0., 1.)));
        // Route north while aiming east: north is to the left.
        assert!(close(reframe(1., 0., 90., 0.), (0., -1.)));
        assert!(close(reframe(1., 0., 30., 30.), (1., 0.)));
        assert!(close(reframe(0., 1., 0., 0.), (0., 1.)));
        assert!(close(reframe(1., 1., 0., 0.), (std::f32::consts::FRAC_1_SQRT_2, std::f32::consts::FRAC_1_SQRT_2)));
        assert_eq!(reframe(f32::NAN, 0., 0., 0.), (0., 0.));
        assert!(close(reframe(1., 0., 179., -179.), (2f32.to_radians().cos(), 2f32.to_radians().sin())));
    }
    #[test] fn strafe_periods_are_bounded_and_neighbours_differ() {
        let (mut a, mut b) = (Strafe::default(), Strafe::default());
        let (mut flips_a, mut flips_b, mut last_a, mut last_b) = (0, 0, 0., 0.);
        let mut since = 0.; let mut max_run: f32 = 0.; let mut differ = 0;
        for n in 0..1200 {
            let t = n as f32 / 60.;
            let sa = a.side(t, 3); let sb = b.side(t, 4);
            assert!(sa == 1. || sa == -1.);
            if sa != last_a { flips_a += 1; max_run = max_run.max(t - since); since = t; }
            if sb != last_b { flips_b += 1; }
            if sa != sb { differ += 1; }
            last_a = sa; last_b = sb;
        }
        assert!(flips_a >= 17 && flips_a <= 51, "{flips_a}");
        assert!(flips_b >= 17);
        assert!(max_run <= Strafe::MAX_PERIOD + 0.02);
        assert!(differ > 100);
    }
    #[test] fn strafe_resets_on_clock_rollback() {
        let mut s = Strafe::default(); s.side(50., 1); s.remember((0., 1.));
        s.side(1., 1); assert_eq!(s.airborne_output(), (0., 0.));
    }
    #[test] fn blocked_step_tries_alternatives_in_order() {
        let mut tried = vec![];
        let got = choose_step(0., 1., |f, s| { tried.push((f, s)); f > 0. && s < 0. });
        assert_eq!(got, Some((0.6, -0.7)));
        assert_eq!(tried[0], (0., 1.)); assert_eq!(tried[1], (0., -1.));
        assert_eq!(choose_step(0., 1., |_, _| false), None);
        assert_eq!(choose_step(-0.45, -1., |f, _| f < 0.), Some((-0.45, -1.)));
    }
    #[test] fn retreat_alternatives_keep_backing_off() {
        let mut tried = vec![];
        choose_step(-0.45, 1., |f, s| { tried.push((f, s)); false });
        assert!(tried.iter().all(|(f, _)| *f < 0.));
        assert_eq!(tried.len(), 6);
    }
}
