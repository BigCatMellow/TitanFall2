//! `bot_personality`: a behavior layer keyed by the weapon a bot carries.
//! It only adjusts movement intent from the existing range controller; aim,
//! firing and the warm-up are untouched.
//!
//! - Rusher (SMGs): keeps pushing until close instead of holding at range,
//!   and only backs off while reloading.
//! - Marksman (G2/DMR/snipers): backs away when an enemy gets inside 600 units.
//! - Anchor (LMGs): holds its lane with smaller strafes.
//! - Rifleman (everything else): unchanged.
//!
//! High-ground seeking for marksmen is deliberately left for a later data-driven step.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Archetype { Rusher, Rifleman, Marksman, Anchor }

pub(super) fn archetype(weapon: &str) -> Archetype {
    match weapon {
        "mp_weapon_car" | "mp_weapon_r97" | "mp_weapon_alternator_smg" | "mp_weapon_hemlok_smg"
        | "mp_weapon_pdw" | "mp_weapon_shotgun" | "mp_weapon_mastiff" | "mp_weapon_shotgun_pistol" => Archetype::Rusher,
        "mp_weapon_g2" | "mp_weapon_dmr" | "mp_weapon_sniper" | "mp_weapon_doubletake" => Archetype::Marksman,
        "mp_weapon_lmg" | "mp_weapon_esaw" => Archetype::Anchor,
        _ => Archetype::Rifleman,
    }
}

impl Archetype {
    pub fn label(self) -> &'static str {
        match self { Self::Rusher => "rusher", Self::Rifleman => "rifleman", Self::Marksman => "marksman", Self::Anchor => "anchor" }
    }
    /// Strafe strength multiplier for in-range holds.
    pub fn strafe_scale(self) -> f32 { if self == Self::Anchor { 0.5 } else { 1. } }
}

/// Adjust the range controller's forward intent (`None` = advance,
/// `Some(0)` = hold, negative = back off).
pub(super) fn adjust_forward(a: Archetype, forward: Option<f32>, visible: bool, distance: f32,
    reloading: bool) -> Option<f32> {
    if !visible || !distance.is_finite() { return forward; }
    match a {
        Archetype::Rusher if reloading => forward,
        Archetype::Rusher if distance > 260. => None,
        Archetype::Rusher => forward.map(|f| f.max(0.)),
        Archetype::Marksman if distance < 600. && !matches!(forward, None) => Some(-0.6),
        _ => forward,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn archetypes_follow_weapon_class() {
        assert_eq!(archetype("mp_weapon_car"), Archetype::Rusher);
        assert_eq!(archetype("mp_weapon_g2"), Archetype::Marksman);
        assert_eq!(archetype("mp_weapon_lmg"), Archetype::Anchor);
        assert_eq!(archetype("mp_weapon_rspn101"), Archetype::Rifleman);
        assert_eq!(archetype("unknown"), Archetype::Rifleman);
    }
    #[test] fn rushers_push_in_and_only_back_off_to_reload() {
        assert_eq!(adjust_forward(Archetype::Rusher, Some(0.), true, 600., false), None);
        assert_eq!(adjust_forward(Archetype::Rusher, Some(-0.45), true, 150., false), Some(0.));
        assert_eq!(adjust_forward(Archetype::Rusher, Some(-0.45), true, 150., true), Some(-0.45));
    }
    #[test] fn marksmen_keep_distance_but_still_approach_from_far() {
        assert_eq!(adjust_forward(Archetype::Marksman, Some(0.), true, 400., false), Some(-0.6));
        assert_eq!(adjust_forward(Archetype::Marksman, Some(0.), true, 900., false), Some(0.));
        assert_eq!(adjust_forward(Archetype::Marksman, None, true, 400., false), None);
    }
    #[test] fn riflemen_anchors_and_unseen_targets_are_unchanged() {
        for f in [None, Some(0.), Some(-0.45)] {
            assert_eq!(adjust_forward(Archetype::Rifleman, f, true, 300., false), f);
            assert_eq!(adjust_forward(Archetype::Anchor, f, true, 300., false), f);
            assert_eq!(adjust_forward(Archetype::Rusher, f, false, 900., false), f);
        }
        assert_eq!(Archetype::Anchor.strafe_scale(), 0.5);
    }
}
