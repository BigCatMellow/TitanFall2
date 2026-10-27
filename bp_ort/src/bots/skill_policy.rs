//! `bot_skill_use`: when to request each pilot tactical/ordnance, replacing the
//! legacy shared time windows (`time % 25 < 10` / `< 3`) that ignored range,
//! sight and intent, and never covered frag grenades or A-Wall at all.
//!
//! Requests still pass through the readiness-gated `Pulse` (bot_action_policy),
//! so an ability on cooldown is never held and never suppresses gunfire.
//! Grapple stays unhandled: it needs traversal logic, not a button press.

#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) struct Situation {
    pub has_target: bool,
    pub visible: bool,
    /// Horizontal distance to the target.
    pub distance: f32,
    /// Target height minus bot height.
    pub height: f32,
    pub health: i32,
    /// In the weapon-range hold (not advancing).
    pub holding: bool,
    /// Advancing on a visible target or pursuing an unseen one.
    pub approaching: bool,
}

fn finite(s: &Situation) -> bool { s.distance.is_finite() && s.height.is_finite() }

/// Reason to press the tactical now, if any.
pub(super) fn tactical(name: &str, s: &Situation) -> Option<&'static str> {
    if !s.has_target || !finite(s) { return None; }
    let hurt = s.health > 0 && s.health < 60;
    match name {
        "mp_ability_heal" if s.visible && hurt => Some("stim_hurt"),
        "mp_ability_heal" if s.visible && s.approaching && (350. ..=1400.).contains(&s.distance) => Some("stim_close_in"),
        "mp_ability_shifter" if s.visible && s.health > 0 && s.health < 45 => Some("phase_escape"),
        "mp_ability_cloak" if !s.visible && s.approaching && s.distance < 1800. => Some("cloak_approach"),
        "mp_ability_cloak" if s.visible && hurt => Some("cloak_disengage"),
        "mp_weapon_grenade_sonar" if !s.visible && (300. ..=1500.).contains(&s.distance) => Some("pulse_reveal"),
        "mp_ability_holopilot" if s.visible && s.distance < 1500. && s.health > 0 && s.health < 80 => Some("holo_decoy"),
        "mp_weapon_deployable_cover" if s.visible && s.holding && s.distance > 500. && s.height.abs() < 150. => Some("awall_hold"),
        _ => None,
    }
}

/// Reason to press the ordnance now plus upward loft in degrees for the throw.
pub(super) fn ordnance(name: &str, s: &Situation) -> Option<(&'static str, f32)> {
    if !s.has_target || !s.visible || !finite(s) { return None; }
    let throwable = matches!(name, "mp_weapon_frag_grenade" | "mp_weapon_grenade_emp"
        | "mp_weapon_thermite_grenade" | "mp_weapon_grenade_gravity");
    if throwable && (250. ..=1100.).contains(&s.distance) && s.height.abs() < 250. {
        return Some(("throw", loft(s.distance)));
    }
    if name == "mp_weapon_grenade_electric_smoke" && s.health > 0 && s.health < 50 && s.distance < 700. {
        return Some(("smoke_cover", 2.));
    }
    None
}

/// Grenades leave along the view; a flat aim at range lands short. Degrees up.
pub(super) fn loft(distance: f32) -> f32 {
    if !distance.is_finite() { return 0.; }
    (4. + (distance - 250.).max(0.) / 850. * 18.).clamp(4., 22.)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn s() -> Situation { Situation { has_target: true, visible: true, distance: 800., height: 0., health: 100, holding: false, approaching: false } }
    #[test] fn stim_closes_distance_or_heals() {
        assert_eq!(tactical("mp_ability_heal", &Situation { approaching: true, ..s() }), Some("stim_close_in"));
        assert_eq!(tactical("mp_ability_heal", &Situation { health: 40, ..s() }), Some("stim_hurt"));
        assert_eq!(tactical("mp_ability_heal", &s()), None);
        assert_eq!(tactical("mp_ability_heal", &Situation { approaching: true, distance: 200., ..s() }), None);
    }
    #[test] fn cloak_and_pulse_work_before_contact() {
        let unseen = Situation { visible: false, approaching: true, ..s() };
        assert_eq!(tactical("mp_ability_cloak", &unseen), Some("cloak_approach"));
        assert_eq!(tactical("mp_weapon_grenade_sonar", &unseen), Some("pulse_reveal"));
        assert_eq!(tactical("mp_weapon_grenade_sonar", &s()), None);
        assert_eq!(tactical("mp_ability_cloak", &Situation { distance: 3000., ..unseen }), None);
    }
    #[test] fn phase_holo_awall_and_grapple() {
        assert_eq!(tactical("mp_ability_shifter", &Situation { health: 30, ..s() }), Some("phase_escape"));
        assert_eq!(tactical("mp_ability_shifter", &Situation { health: 50, ..s() }), None);
        assert_eq!(tactical("mp_ability_holopilot", &Situation { health: 70, ..s() }), Some("holo_decoy"));
        assert_eq!(tactical("mp_weapon_deployable_cover", &Situation { holding: true, ..s() }), Some("awall_hold"));
        assert_eq!(tactical("mp_weapon_deployable_cover", &Situation { holding: true, height: 300., ..s() }), None);
        assert_eq!(tactical("mp_ability_grapple", &Situation { health: 10, ..s() }), None);
        assert_eq!(tactical("mp_ability_heal", &Situation { has_target: false, health: 10, ..s() }), None);
    }
    #[test] fn grenades_need_sight_range_and_level_and_get_loft() {
        let (reason, l) = ordnance("mp_weapon_frag_grenade", &s()).unwrap();
        assert_eq!(reason, "throw"); assert!(l > 4. && l < 22.);
        assert_eq!(ordnance("mp_weapon_frag_grenade", &Situation { distance: 150., ..s() }), None);
        assert_eq!(ordnance("mp_weapon_frag_grenade", &Situation { distance: 1500., ..s() }), None);
        assert_eq!(ordnance("mp_weapon_grenade_emp", &Situation { height: 400., ..s() }), None);
        assert_eq!(ordnance("mp_weapon_thermite_grenade", &Situation { visible: false, ..s() }), None);
        assert_eq!(ordnance("mp_weapon_satchel", &s()), None);
        assert_eq!(ordnance("mp_weapon_grenade_electric_smoke", &Situation { health: 30, distance: 400., ..s() }), Some(("smoke_cover", 2.)));
        assert_eq!(ordnance("mp_weapon_frag_grenade", &Situation { distance: f32::NAN, ..s() }), None);
    }
    #[test] fn loft_grows_with_range_and_is_bounded() {
        assert_eq!(loft(100.), 4.); assert!(loft(675.) > 12. && loft(675.) < 14.);
        assert_eq!(loft(5000.), 22.); assert_eq!(loft(f32::NAN), 0.);
    }
}
