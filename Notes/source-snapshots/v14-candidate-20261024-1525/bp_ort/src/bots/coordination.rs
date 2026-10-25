//! Team-local pursuit claims. This never prevents attacking an available foe.
#[derive(Clone, Copy, Debug)]
pub(super) struct Candidate {
    pub id: i32,
    pub distance: f32,
}

#[derive(Clone, Copy, Debug)]
struct Claim {
    team: i32,
    target: i32,
    changed_at: f32,
    updated_at: f32,
}

#[derive(Debug)]
pub(super) struct Coordinator {
    claims: [Option<Claim>; 64],
}

impl Default for Coordinator {
    fn default() -> Self { Self { claims: [None; 64] } }
}

impl Coordinator {
    fn active(claim: &Claim, now: f32) -> bool {
        now >= claim.updated_at && now - claim.updated_at <= 1.
    }

    pub fn clear(&mut self, bot: usize) {
        if let Some(claim) = self.claims.get_mut(bot) { *claim = None; }
    }

    pub fn supporters(&self, bot: usize, team: i32, target: i32, now: f32) -> usize {
        self.claims.iter().enumerate().filter(|(slot, claim)| {
            *slot != bot && claim.is_some_and(|c| Self::active(&c, now)
                && c.team == team && c.target == target)
        }).count()
    }

    pub fn commit(&mut self, bot: usize, team: i32, target: i32, now: f32) {
        let Some(slot) = self.claims.get_mut(bot) else { return; };
        let changed_at = slot.filter(|old| Self::active(old, now)
            && old.team == team && old.target == target).map_or(now, |old| old.changed_at);
        *slot = Some(Claim { team, target, changed_at, updated_at: now });
    }

    pub fn rank(&self, bot: usize, team: i32, now: f32, candidates: &[Candidate]) -> Vec<usize> {
        let mut order: Vec<_> = (0..candidates.len()).filter(|i| {
            candidates[*i].distance.is_finite() && candidates[*i].distance >= 0.
        }).collect();
        let nearest = order.iter().map(|i| candidates[*i].distance).fold(f32::INFINITY, f32::min);
        let previous = self.claims.get(bot).copied().flatten()
            .filter(|c| Self::active(c, now) && c.team == team);
        let score = |index: usize| {
            let c = candidates[index];
            // Nearby threats win regardless of claims or commitment time.
            let urgent = c.distance <= 400.;
            let held = !urgent && nearest > 400. && previous.is_some_and(|p|
                p.target == c.id && now - p.changed_at < 1.5 && c.distance <= nearest + 900.);
            let assigned = self.supporters(bot, team, c.id, now) as f32;
            // Remain strictly increasing without sending bots across the map
            // merely because a nearby opponent already has several pursuers.
            let pressure = 1400. * assigned / (assigned + 2.);
            let continuity = if previous.is_some_and(|p| p.target == c.id) { 0.85 } else { 1. };
            let cost = if urgent { c.distance } else { c.distance * continuity + pressure };
            (if urgent { 0 } else if held { 1 } else { 2 }, cost)
        };
        order.sort_by(|a, b| {
            let (class_a, cost_a) = score(*a);
            let (class_b, cost_b) = score(*b);
            class_a.cmp(&class_b).then_with(|| cost_a.total_cmp(&cost_b)).then_with(|| a.cmp(b))
        });
        order
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn c(id: i32, distance: f32) -> Candidate { Candidate { id, distance } }

    #[test]
    fn eight_teammates_share_two_equally_reachable_targets() {
        let mut coordinator = Coordinator::default();
        let candidates = [c(10, 1000.), c(11, 1000.)];
        let mut assigned = [0; 2];
        for bot in 0..8 {
            let selected = coordinator.rank(bot, 2, 0., &candidates)[0];
            assigned[selected] += 1;
            coordinator.commit(bot, 2, candidates[selected].id, 0.);
        }
        assert_eq!(assigned, [4, 4]);
    }

    #[test]
    fn claims_from_another_team_do_not_affect_selection() {
        let mut coordinator = Coordinator::default();
        for bot in 0..8 { coordinator.commit(bot, 3, 10, 0.); }
        assert_eq!(coordinator.rank(9, 2, 0.1, &[c(10, 1000.), c(11, 1100.)])[0], 0);
    }

    #[test]
    fn dead_expired_and_previous_map_claims_are_ignored() {
        let mut coordinator = Coordinator::default();
        coordinator.commit(0, 2, 10, 5.);
        assert_eq!(coordinator.supporters(1, 2, 10, 5.2), 1);
        coordinator.clear(0);
        assert_eq!(coordinator.supporters(1, 2, 10, 5.2), 0);
        coordinator.commit(0, 2, 10, 5.);
        assert_eq!(coordinator.supporters(1, 2, 10, 6.1), 0);
        assert_eq!(coordinator.supporters(1, 2, 10, 0.), 0);
    }

    #[test]
    fn commitment_prevents_churn_but_does_not_ignore_nearby_danger() {
        let mut coordinator = Coordinator::default();
        coordinator.commit(0, 2, 10, 0.);
        assert_eq!(coordinator.rank(0, 2, 0.2, &[c(10, 1000.), c(11, 700.)])[0], 0);
        assert_eq!(coordinator.rank(0, 2, 0.2, &[c(10, 1000.), c(11, 100.)])[0], 1);
        coordinator.commit(0, 2, 10, 0.9);
        coordinator.commit(0, 2, 10, 1.4);
        assert_eq!(coordinator.rank(0, 2, 1.6, &[c(10, 1000.), c(11, 700.)])[0], 1);
    }

    #[test]
    fn one_available_enemy_is_never_blocked_and_pressure_is_bounded() {
        let mut coordinator = Coordinator::default();
        for bot in 0..8 { coordinator.commit(bot, 2, 10, 0.); }
        assert_eq!(coordinator.rank(9, 2, 0.1, &[c(10, 1000.)]), [0]);
        assert_eq!(coordinator.rank(9, 2, 0.1, &[c(10, 1000.), c(11, 5000.)])[0], 0);
        assert!(coordinator.rank(9, 2, 0.1, &[c(12, f32::NAN)]).is_empty());
    }

    #[test]
    fn spacing_ignores_other_floors_and_diverges_at_a_head_on_blockage() {
        assert_eq!(separation_side(0, 0., [0.; 3], &[[0., 50., 300.]]), (0., 0));
        let (even, neighbors) = separation_side(0, 0., [0.; 3], &[[50., 0., 0.]]);
        let (odd, _) = separation_side(1, 0., [0.; 3], &[[50., 0., 0.]]);
        assert_eq!(neighbors, 1);
        assert!(even > 0. && odd < 0.);
        assert!(separation_side(0, 0., [0.; 3], &[[0., 50., 0.]]).0 > 0.);
    }
}

pub(super) fn separation_side(bot: usize, yaw: f32, origin: [f32; 3], allies: &[[f32; 3]]) -> (f32, usize) {
    let mut lateral = 0.;
    let mut count = 0;
    let yaw = yaw.to_radians();
    for ally in allies {
        let dx = origin[0] - ally[0];
        let dy = origin[1] - ally[1];
        let length = (dx * dx + dy * dy).sqrt();
        if length < 140. && (origin[2] - ally[2]).abs() < 96. {
            count += 1;
            if length > 1. {
                lateral += (dx * yaw.sin() - dy * yaw.cos()) / length * (1. - length / 140.);
            }
        }
    }
    if count > 0 && lateral.abs() < 0.1 { lateral = if bot % 2 == 0 { 0.6 } else { -0.6 }; }
    (lateral.clamp(-0.7, 0.7), count)
}
