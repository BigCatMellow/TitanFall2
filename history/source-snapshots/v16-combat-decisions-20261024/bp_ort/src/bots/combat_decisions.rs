//! Pilot combat choices without native memory or navigation ownership.
#[derive(Clone, Copy, Debug)]
struct Profile { near: f32, far: f32, reloadable: bool }
fn profile(name: &str) -> Option<Profile> {
    let (near, far, reloadable) = match name {
        "mp_weapon_shotgun" | "mp_weapon_shotgun_pistol" | "mp_weapon_shotgun_doublebarrel" => (90., 300., true),
        "mp_weapon_car" | "mp_weapon_hemlok_smg" | "mp_weapon_r97" | "mp_weapon_pdw" | "mp_weapon_autopistol" => (180., 650., true),
        "mp_weapon_rspn101" | "mp_weapon_rspn101_og" | "mp_weapon_vinson" | "mp_weapon_hemlok" | "mp_weapon_lmg" => (280., 1000., true),
        "mp_weapon_g2" | "mp_weapon_wingman_n" | "mp_weapon_dmr" | "mp_weapon_doubletake" | "mp_weapon_sniper" => (400., 1350., true),
        "mp_weapon_epg" | "mp_weapon_smr" | "mp_weapon_softball" => (300., 850., true),
        "mp_weapon_lstar" => (240., 900., false),
        _ => return None,
    };
    Some(Profile { near, far, reloadable })
}
#[derive(Clone, Copy, Debug, Default)]
pub(super) struct Decision {
    pub forward: Option<f32>,
    pub side: f32,
    pub reload: bool,
    pub suppress_fire: bool,
}
pub(super) struct Input<'a> {
    pub now: f32, pub weapon_id: i32, pub weapon: &'a str, pub clip: i32,
    pub reloading: bool, pub visible: bool, pub distance: f32, pub height: f32, pub slot: u16,
}
#[derive(Debug)]
pub(super) struct CombatState {
    pub weapon: String, pub clip: i32, pub reloading: bool, pub tactic: &'static str,
    pub reload_requests: u32, pub holds: u32, pub retreats: u32, pub blocked_steps: u32,
    weapon_id: i32, max_clip: i32, last_visible: f32, last_reload: f32,
    holding: bool, retreat_at: Option<f32>, last_time: f32,
    pub step_next_at: f32, pub step_clear: bool, pub step_yaw: f32, pub step_side: f32, pub step_forward: f32,
}
impl Default for CombatState {
    fn default() -> Self { Self {
        weapon: String::new(), clip: 0, reloading: false, tactic: "legacy",
        reload_requests: 0, holds: 0, retreats: 0, blocked_steps: 0,
        weapon_id: -1, max_clip: 0, last_visible: 0., last_reload: -100.,
        holding: false, retreat_at: None, last_time: 0.,
        step_next_at: 0., step_clear: false, step_yaw: 0., step_side: 0., step_forward: 0.,
    } }
}
impl CombatState {
    pub fn decide(&mut self, i: Input<'_>) -> Decision {
        if !i.now.is_finite() || i.now < self.last_time { *self = Self::default(); return Decision::default(); }
        self.last_time = i.now;
        if self.weapon_id != i.weapon_id || self.weapon != i.weapon {
            self.weapon_id = i.weapon_id;
            self.weapon = i.weapon.to_owned();
            self.max_clip = 0;
            self.holding = false;
            self.retreat_at = None;
            self.last_reload = -100.;
            self.last_visible = i.now;
            self.step_next_at = 0.;
        }
        self.clip = i.clip;
        self.reloading = i.reloading;
        self.max_clip = self.max_clip.max(i.clip.clamp(0, 10000));
        let mut d = Decision::default();
        let old = self.tactic;
        self.tactic = "legacy";
        let Some(p) = profile(i.weapon) else { return d; };
        if i.clip < 0 { return d; }
        if i.visible { self.last_visible = i.now; }
        let quiet_low = !i.visible && i.now - self.last_visible >= 1.25
            && self.max_clip >= 4 && i.clip > 0 && i.clip <= self.max_clip / 3;
        let empty = i.clip == 0;
        if p.reloadable && !i.reloading && (empty || quiet_low) && i.now - self.last_reload >= 0.75 {
            d.reload = true;
            self.last_reload = i.now;
            self.reload_requests = self.reload_requests.saturating_add(1);
        }
        d.suppress_fire = p.reloadable && (empty || i.reloading || d.reload);
        self.tactic = if d.suppress_fire { "reload" } else { "advance" };
        if i.visible && i.distance.is_finite() && i.distance >= 0. && i.height.is_finite() && i.height.abs() <= 180. {
            let limit = p.far + if self.holding { 100. } else { 0. };
            self.holding = i.distance <= limit;
            if self.holding {
                d.forward = Some(0.);
                d.side = if ((i.now + i.slot as f32 * 0.43) / 3.2).floor() as u32 % 2 == 0 { 0.3 } else { -0.3 };
                self.tactic = if d.suppress_fire { "reload_hold" } else { "range_hold" };
                let close = i.distance < p.near || (d.suppress_fire && i.distance < 450.);
                if close {
                    let at = *self.retreat_at.get_or_insert(i.now);
                    if i.now - at <= 0.6 {
                        d.forward = Some(-0.45);
                        self.tactic = if d.suppress_fire { "reload_retreat" } else { "range_retreat" };
                    }
                } else if i.distance > p.near + 100. { self.retreat_at = None; }
            } else { self.retreat_at = None; }
        } else { self.holding = false; self.retreat_at = None; }
        if self.tactic != old {
            if self.tactic.ends_with("hold") { self.holds = self.holds.saturating_add(1); }
            if self.tactic.ends_with("retreat") { self.retreats = self.retreats.saturating_add(1); }
        }
        d
    }
}
pub(super) fn pilot_melee(dx: f32, dy: f32, dz: f32) -> bool {
    dx.is_finite() && dy.is_finite() && dz.is_finite()
        && dx * dx + dy * dy <= 90. * 90. && dz.abs() <= 55.
}
#[cfg(test)]
mod tests {
    use super::*;
    fn input(now: f32) -> Input<'static> { Input { now, weapon_id: 1, weapon: "mp_weapon_car", clip: 30,
        reloading: false, visible: true, distance: 500., height: 0., slot: 1 } }
    #[test] fn weapons_choose_different_engagement_distances() {
        let mut s = CombatState::default(); let mut i = input(1.);
        i.weapon = "mp_weapon_shotgun"; assert_eq!(s.decide(i).forward, None);
        let mut i = input(2.); i.weapon = "mp_weapon_sniper"; assert_eq!(s.decide(i).forward, Some(0.));
    }
    #[test] fn range_hysteresis_prevents_boundary_chatter() {
        let mut s = CombatState::default(); assert_eq!(s.decide(input(1.)).forward, Some(0.));
        let mut i = input(2.); i.distance = 700.; assert_eq!(s.decide(i).forward, Some(0.));
        let mut i = input(3.); i.distance = 800.; assert_eq!(s.decide(i).forward, None);
    }
    #[test] fn visible_low_ammo_does_not_start_tactical_reload() {
        let mut s = CombatState::default(); s.decide(input(1.));
        let mut i = input(2.); i.clip = 2; assert!(!s.decide(i).reload);
    }
    #[test] fn low_ammo_reloads_after_losing_contact_not_immediately() {
        let mut s = CombatState::default(); s.decide(input(1.));
        let mut i = input(1.5); i.visible = false; i.clip = 5; assert!(!s.decide(i).reload);
        let mut i = input(2.3); i.visible = false; i.clip = 5; assert!(s.decide(i).reload);
    }
    #[test] fn empty_reload_is_throttled_and_suppresses_empty_firing() {
        let mut s = CombatState::default(); let mut i = input(1.); i.clip = 0;
        let d = s.decide(i); assert!(d.reload && d.suppress_fire);
        let mut i = input(1.1); i.clip = 0; assert!(!s.decide(i).reload);
        let mut i = input(1.8); i.clip = 0; assert!(s.decide(i).reload);
    }
    #[test] fn reload_is_allowed_to_complete_without_new_reload_requests() {
        let mut s = CombatState::default(); let mut i = input(1.); i.reloading = true;
        let d = s.decide(i); assert!(!d.reload && d.suppress_fire);
    }
    #[test] fn retreat_is_bounded_then_holds_without_repeating_forever() {
        let mut s = CombatState::default(); let mut i = input(1.); i.distance = 100.;
        assert_eq!(s.decide(i).forward, Some(-0.45));
        let mut i = input(1.7); i.distance = 100.; assert_eq!(s.decide(i).forward, Some(0.));
        let mut i = input(5.); i.distance = 100.; assert_eq!(s.decide(i).forward, Some(0.));
    }
    #[test] fn weapon_switch_resets_magazine_estimate() {
        let mut s = CombatState::default(); s.decide(input(1.));
        let mut i = input(2.); i.weapon_id = 2; i.weapon = "mp_weapon_sniper"; i.clip = 4; i.visible = false;
        assert!(!s.decide(i).reload);
        assert_eq!(s.max_clip, 4);
    }
    #[test] fn unknown_and_heat_weapons_do_not_get_ammo_reload_commands() {
        let mut s = CombatState::default();
        for weapon in ["mp_weapon_lstar", "mp_weapon_defender", "unknown"] {
            let mut i = input(1.); i.weapon = weapon; i.clip = 0;
            let d = s.decide(i); assert!(!d.reload && !d.suppress_fire);
        }
    }
    #[test] fn bad_geometry_or_different_floor_cannot_create_retreat() {
        let mut s = CombatState::default();
        for distance in [f32::NAN, f32::INFINITY, -1.] {
            let mut i = input(1.); i.distance = distance; assert_eq!(s.decide(i).forward, None);
        }
        let mut i = input(2.); i.height = 300.; assert_eq!(s.decide(i).forward, None);
    }
    #[test] fn neighbors_strafe_with_offset_phases() {
        let mut a = CombatState::default(); let mut b = CombatState::default();
        let i = input(1.); let da = a.decide(i); let mut i = input(1.); i.slot = 8;
        assert_eq!(da.side, -b.decide(i).side);
    }
    #[test] fn melee_distance_is_circular_and_does_not_reach_down_map_axes() {
        assert!(pilot_melee(60., 60., 0.)); assert!(!pilot_melee(70., 70., 0.));
        assert!(!pilot_melee(0., 2000., 0.)); assert!(!pilot_melee(2000., 0., 0.));
        assert!(!pilot_melee(0., 0., 100.)); assert!(!pilot_melee(f32::NAN, 0., 0.));
    }
    #[test] fn clock_reset_and_default_clear_engagement_state() {
        let mut s = CombatState::default(); s.decide(input(20.)); s.decide(input(1.));
        assert!(s.weapon.is_empty()); assert!(!s.holding); assert!(s.retreat_at.is_none());
    }
}
