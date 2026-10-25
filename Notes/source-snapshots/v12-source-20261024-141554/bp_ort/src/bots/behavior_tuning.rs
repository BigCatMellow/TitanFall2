//! Pure aiming/steering calculations, independent of native engine memory.
pub(super) fn turn_yaw(current: f32, target: f32, max_step: f32) -> f32 {
    let current = if current.is_finite() { current } else { 0. };
    if !target.is_finite() || !max_step.is_finite() {
        return current;
    }
    let delta = (target - current + 180.).rem_euclid(360.) - 180.;
    (current + delta.clamp(-max_step.abs(), max_step.abs()) + 180.).rem_euclid(360.) - 180.
}

pub(super) fn aim_error_scale(value: f32) -> f32 {
    if value.is_finite() { value.clamp(0.25, 2.) } else { 1. }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn facing_across_the_angle_seam_uses_the_two_degree_turn() {
        assert_eq!(turn_yaw(179., -179., 10.), -179.);
        assert_eq!(turn_yaw(-179., 179., 10.), 179.);
    }
    #[test]
    fn navigation_turns_are_bounded_and_work_with_unwrapped_angles() {
        assert_eq!(turn_yaw(0., 150., 9.), 9.);
        assert_eq!(turn_yaw(0., -150., 9.), -9.);
        assert_eq!(turn_yaw(539., -179., 10.), -179.);
        assert_eq!(turn_yaw(30., 40., 0.), 30.);
    }
    #[test]
    fn invalid_settings_cannot_inject_nonfinite_angles() {
        assert_eq!(aim_error_scale(f32::NAN), 1.);
        assert_eq!(aim_error_scale(f32::INFINITY), 1.);
        assert_eq!(aim_error_scale(-1.), 0.25);
        assert_eq!(turn_yaw(45., f32::NAN, 10.), 45.);
        assert!(turn_yaw(f32::NAN, 90., 10.).is_finite());
    }
}
