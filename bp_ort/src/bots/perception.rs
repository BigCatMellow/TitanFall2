//! Geometry helpers for `bot_perception_fix` and `bot_proximity_fix`.
//!
//! The legacy field-of-view test dotted a direction with `view_angles` and
//! compared against cos(270 deg) == 0: at best a 180-degree hemisphere, and an
//! arbitrary yaw-dependent half-plane if that function returns degrees. The fix
//! derives a forward vector from the known eye angles (degrees) and keeps the
//! same effective 180-degree hemisphere, so awareness is not widened.

/// Horizontal forward unit vector from Source angles in degrees.
pub(super) fn forward_xy(yaw_deg: f32) -> Option<[f32; 2]> {
    yaw_deg.is_finite().then(|| { let (s, c) = yaw_deg.to_radians().sin_cos(); [c, s] })
}

/// True when `to` (target minus observer, any length) is in the front hemisphere.
pub(super) fn in_front_hemisphere(yaw_deg: f32, to: [f32; 3]) -> bool {
    let Some(f) = forward_xy(yaw_deg) else { return false; };
    let len = (to[0] * to[0] + to[1] * to[1]).sqrt();
    if !len.is_finite() { return false; }
    if len < 1. { return true; } // directly above/below: not a facing question
    (f[0] * to[0] + f[1] * to[1]) / len > 0.
}

/// Corrected proximity: the legacy code multiplied dx^2 by dy^2, which is near
/// zero whenever either axis is aligned, however far away the other one is.
pub(super) fn within_xy(dx: f32, dy: f32, radius_sq: f32) -> bool {
    dx.is_finite() && dy.is_finite() && dx * dx + dy * dy < radius_sq
}

/// Point to test sight against on a target: its eye height when known,
/// otherwise most of its collision height, bounded to sane values.
pub(super) fn target_sight_height(maxs_z: f32) -> f32 {
    if maxs_z.is_finite() && maxs_z > 10. { (maxs_z * 0.85).clamp(20., 400.) } else { 48. }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn hemisphere_uses_yaw_not_raw_angle_values() {
        assert!(in_front_hemisphere(0., [100., 10., 0.]));
        assert!(!in_front_hemisphere(0., [-100., 10., 0.]));
        assert!(in_front_hemisphere(180., [-100., 10., 0.]));
        assert!(in_front_hemisphere(90., [5., 100., 0.]));
        assert!(!in_front_hemisphere(-90., [5., 100., 0.]));
        assert!(in_front_hemisphere(0., [0., 0., 300.]));
        assert!(!in_front_hemisphere(f32::NAN, [1., 0., 0.]));
    }
    #[test] fn proximity_is_circular() {
        assert!(!within_xy(0., 2000., 81000.)); // legacy product: 0 * big < 81000 == true
        assert!(within_xy(200., 200., 81000.));
        assert!(!within_xy(300., 0., 81000.));
        assert!(!within_xy(f32::NAN, 0., 81000.));
    }
    #[test] fn sight_height_is_bounded() {
        assert!((target_sight_height(72.) - 61.2).abs() < 1e-3);
        assert_eq!(target_sight_height(f32::NAN), 48.);
        assert_eq!(target_sight_height(1000.), 400.);
    }
}
