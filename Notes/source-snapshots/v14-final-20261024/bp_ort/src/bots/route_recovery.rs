//! Bounded, short-lived navigation memory. Contains no engine pointers.
type Point = [f32; 3];
const CAPACITY: usize = 8;

/// Popping the final node makes the queue empty, but the active waypoint
/// still needs to be walked to. Do not rebuild that route every command.
pub(super) fn route_exhausted(queued: usize, has_goal: bool, waypoint_distance: f32) -> bool {
    queued == 0 && (!has_goal || !waypoint_distance.is_finite() || waypoint_distance <= 45.)
}

fn horizontal(a: Point, b: Point) -> f32 {
    (a[0] - b[0]).hypot(a[1] - b[1])
}
fn near(a: Point, b: Point, radius: f32) -> bool {
    horizontal(a, b) <= radius && (a[2] - b[2]).abs() <= 128.
}

#[derive(Clone, Copy, Debug)]
struct Failure { source: Point, goal: Point, at: f32, count: u8 }
#[derive(Clone, Copy, Debug)]
struct Escape { goal: Point, until: f32 }

#[derive(Debug, Default)]
pub(super) struct RouteRecovery {
    failures: [Option<Failure>; CAPACITY],
    failure_cursor: usize,
    breadcrumbs: [Option<Point>; CAPACITY],
    breadcrumb_cursor: usize,
    last_position: Option<Point>,
    episode: Option<(f32, Point, u8)>,
    escape: Option<Escape>,
}

impl RouteRecovery {
    pub fn observe(&mut self, pos: Point) {
        if !pos.iter().all(|v| v.is_finite()) { return; }
        // Respawns/teleports must not leave a trail across the map.
        if self.last_position.is_some_and(|p| horizontal(p, pos) > 1000.
            || (p[2] - pos[2]).abs() > 512.) { *self = Self::default(); }
        self.last_position = Some(pos);
        if self.episode.is_some_and(|(_, anchor, _)| horizontal(anchor, pos) > 256.) {
            self.episode = None;
        }
        let last = (self.breadcrumb_cursor + CAPACITY - 1) % CAPACITY;
        if self.breadcrumbs[last].is_none_or(|p| horizontal(p, pos) >= 128.) {
            self.breadcrumbs[self.breadcrumb_cursor] = Some(pos);
            self.breadcrumb_cursor = (self.breadcrumb_cursor + 1) % CAPACITY;
        }
    }

    pub fn fail(&mut self, now: f32, source: Point, goal: Point) {
        if !now.is_finite() || !source.iter().chain(goal.iter()).all(|v| v.is_finite()) { return; }
        if let Some(failure) = self.failures.iter_mut().flatten().find(|f|
            now >= f.at && now - f.at < 12. && near(source, f.source, 192.) && near(goal, f.goal, 320.)) {
            failure.at = now;
            failure.count = failure.count.saturating_add(1).min(4);
            return;
        }
        self.failures[self.failure_cursor] = Some(Failure { source, goal, at: now, count: 1 });
        self.failure_cursor = (self.failure_cursor + 1) % CAPACITY;
    }

    pub fn blocked(&self, now: f32, source: Point, goal: Point) -> bool {
        self.failures.iter().flatten().any(|f| now >= f.at
            && now - f.at < (2. * f.count as f32).min(8.)
            && near(source, f.source, 192.) && near(goal, f.goal, 320.))
    }

    // Visible threats bypass failed-route memory; the only enemy is never
    // discarded. Memory changes unseen pursuit choices, not combat aim.
    pub fn select(&self, visible: Option<usize>, ranked: &[usize], goals: &[Point],
        now: f32, source: Point) -> Option<usize> {
        visible.or_else(|| ranked.iter().copied().find(|i|
            goals.get(*i).is_some_and(|goal| !self.blocked(now, source, *goal))))
            .or_else(|| ranked.first().copied())
    }

    /// Return a previously traversed retreat destination on repeated stalls.
    pub fn stalled(&mut self, now: f32, source: Point, goal: Point) -> Option<Point> {
        let count = self.episode.filter(|(at, p, _)| now >= *at && now - *at < 12.
            && near(source, *p, 192.)).map_or(1, |(_, _, n)| n.saturating_add(1));
        self.episode = Some((now, source, count));
        if count < 2 { return None; }
        self.fail(now, source, goal);
        let retreat = (1..=CAPACITY).find_map(|offset| {
            let pos = self.breadcrumbs[(self.breadcrumb_cursor + CAPACITY - offset) % CAPACITY]?;
            let d = horizontal(pos, source);
            (d >= 160. && d <= 600. && (pos[2] - source[2]).abs() <= 96.).then_some(pos)
        });
        self.escape = retreat.map(|goal| Escape { goal, until: now + 3. });
        retreat
    }

    pub fn escape_goal(&mut self, now: f32, source: Point) -> Option<Point> {
        let escape = self.escape?;
        if now >= escape.until || now < escape.until - 3. || near(source, escape.goal, 64.) {
            self.escape = None;
            None
        } else { Some(escape.goal) }
    }

    pub fn cancel_escape(&mut self) { self.escape = None; }
    pub fn has_escape(&self) -> bool { self.escape.is_some() }
    pub fn attempts(&self) -> u8 { self.episode.map_or(0, |(_, _, n)| n) }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn popped_terminal_waypoint_remains_active_until_reached() {
        let mut queue = vec![400., 0.];
        let _start = queue.pop();
        let active = queue.pop().unwrap();
        assert!(!route_exhausted(queue.len(), true, active));
        assert!(!route_exhausted(queue.len(), true, 200.));
        assert!(route_exhausted(queue.len(), true, 40.));
    }
    #[test]
    fn missing_route_or_invalid_active_waypoint_requires_refresh() {
        assert!(route_exhausted(0, false, 400.));
        assert!(route_exhausted(0, true, f32::NAN));
        assert!(!route_exhausted(1, true, 0.));
    }
    #[test]
    fn failure_expires_and_does_not_follow_bot_or_moving_target() {
        let mut r = RouteRecovery::default();
        r.fail(10., [0.;3], [1000.,0.,0.]);
        assert!(r.blocked(11., [0.;3], [1100.,0.,0.]));
        assert!(!r.blocked(12., [0.;3], [1000.,0.,0.]));
        assert!(!r.blocked(9., [0.;3], [1000.,0.,0.]));
        assert!(!r.blocked(11., [250.,0.,0.], [1000.,0.,0.]));
        assert!(!r.blocked(11., [0.;3], [1400.,0.,0.]));
        assert!(!r.blocked(11., [0.;3], [1000.,0.,300.]));
    }
    #[test]
    fn alternate_pursuit_preserves_visible_and_only_enemy() {
        let mut r = RouteRecovery::default();
        let goals = [[1000.,0.,0.], [2000.,0.,0.]];
        r.fail(10., [0.;3], goals[0]);
        assert_eq!(r.select(None, &[0,1], &goals, 11., [0.;3]), Some(1));
        assert_eq!(r.select(Some(0), &[0,1], &goals, 11., [0.;3]), Some(0));
        assert_eq!(r.select(None, &[0], &goals, 11., [0.;3]), Some(0));
        r.fail(10., [0.;3], goals[1]);
        assert_eq!(r.select(None, &[0,1], &goals, 11., [0.;3]), Some(0));
        assert_eq!(r.select(None, &[], &goals, 11., [0.;3]), None);
    }
    #[test]
    fn memory_is_bounded_even_after_many_distinct_failures() {
        let mut r = RouteRecovery::default();
        for i in 0..100 { r.fail(10., [0.;3], [i as f32 * 1000.,0.,0.]); }
        assert_eq!(r.failures.iter().flatten().count(), CAPACITY);
        assert!(!r.blocked(11., [0.;3], [0.;3]));
    }
    #[test]
    fn repeated_stall_retreats_to_recent_ground_and_finishes() {
        let mut r = RouteRecovery::default();
        for x in [0.,128.,256.,384.] { r.observe([x,0.,0.]); }
        assert_eq!(r.stalled(3., [384.,0.,0.], [1000.,0.,0.]), None);
        assert_eq!(r.stalled(6., [384.,0.,0.], [1000.,0.,0.]), Some([128.,0.,0.]));
        assert_eq!(r.escape_goal(7., [384.,0.,0.]), Some([128.,0.,0.]));
        assert_eq!(r.escape_goal(8., [140.,0.,0.]), None);
        assert!(r.blocked(7., [384.,0.,0.], [1000.,0.,0.]));
    }
    #[test]
    fn no_breadcrumb_or_other_floor_never_invents_a_waypoint() {
        let mut r = RouteRecovery::default();
        r.observe([0.,0.,300.]); r.observe([256.,0.,0.]);
        r.stalled(3., [256.,0.,0.], [1000.,0.,0.]);
        assert_eq!(r.stalled(6., [256.,0.,0.], [1000.,0.,0.]), None);
        assert_eq!(r.attempts(), 2);
    }
    #[test]
    fn teleport_and_real_progress_clear_recovery_episode() {
        let mut r = RouteRecovery::default();
        r.observe([0.;3]); r.stalled(3., [0.;3], [1000.,0.,0.]);
        r.observe([300.,0.,0.]); assert_eq!(r.attempts(), 0);
        r.fail(5., [300.,0.,0.], [1000.,0.,0.]);
        r.observe([2000.,0.,0.]);
        assert!(!r.blocked(6., [300.,0.,0.], [1000.,0.,0.]));
    }
    #[test]
    fn escape_has_a_deadline_and_cancels_when_threat_is_visible() {
        let mut r = RouteRecovery::default();
        for x in [0.,128.,256.,384.] { r.observe([x,0.,0.]); }
        r.stalled(3., [384.,0.,0.], [1000.,0.,0.]);
        r.stalled(6., [384.,0.,0.], [1000.,0.,0.]);
        assert_eq!(r.escape_goal(9., [384.,0.,0.]), None);
        r.stalled(10., [384.,0.,0.], [1000.,0.,0.]);
        r.cancel_escape(); assert_eq!(r.escape_goal(11., [384.,0.,0.]), None);
    }
}
