//! Bounded input requests. Readiness comes from script APIs, not memory offsets.
#[derive(Clone, Copy, Debug)]
pub(super) struct Ready { pub at: f32, pub weapon: i32, pub ready: bool }
impl Ready {
    pub fn permits(self, now: f32, weapon: i32) -> bool {
        self.matches(now, weapon) && self.ready
    }
    fn matches(self, now: f32, weapon: i32) -> bool {
        now.is_finite() && self.at.is_finite() && weapon != -1 && self.weapon == weapon
            && now >= self.at && now - self.at <= 0.35
    }
}
#[derive(Debug, Default)]
pub(super) struct Pulse {
    weapon: Option<i32>, until: f32, next: f32, last: Option<f32>,
    pub starts: u32, pub blocked: u32,
}
impl Pulse {
    pub fn press(&mut self, now: f32, weapon: i32, wanted: bool, ready: Option<Ready>) -> bool {
        self.press_for(now, weapon, wanted, ready, 0.12, false)
    }
    pub fn press_with_interval(&mut self, now:f32, weapon:i32, wanted:bool, ready:Option<Ready>, interval:f32)->bool {
        self.press_for_interval(now,weapon,wanted,ready,0.12,false,interval)
    }
    pub fn press_for(&mut self, now:f32, weapon:i32, wanted:bool, ready:Option<Ready>, hold:f32, committed:bool)->bool {
        self.press_for_interval(now,weapon,wanted,ready,hold,committed,1.)
    }
    pub fn press_for_interval(&mut self, now:f32, weapon:i32, wanted:bool, ready:Option<Ready>, hold:f32, committed:bool, interval:f32)->bool {
        if !now.is_finite() || !hold.is_finite() || !interval.is_finite() || interval<1. {return false;}
        if self.last.is_some_and(|last| now < last) || self.weapon != Some(weapon) {
            *self = Self { weapon: Some(weapon), ..Default::default() };
        }
        self.last = Some(now);
        // A started toss may become busy during pullout. Finish only its bounded
        // input pulse; starting still requires explicit readiness every time.
        let permitted = ready.is_some_and(|r| r.permits(now, weapon)
            || (committed && now < self.until && r.matches(now, weapon)));
        if !wanted || !permitted {
            self.until = now;
            if wanted { self.blocked = self.blocked.saturating_add(1); }
            return false;
        }
        if now < self.until { return true; }
        if now < self.next { return false; }
        self.until = now + hold.clamp(0.05, 0.6);
        self.next = now + interval;
        self.starts = self.starts.saturating_add(1);
        true
    }
}
pub(super) fn eligible_target(now: f32, sample: Option<(f32, bool)>) -> bool {
    sample.is_some_and(|(at, eligible)| now.is_finite() && at.is_finite()
        && now >= at && now - at <= 0.35 && eligible)
}
pub(super) fn clear_side(side: f32, retry: bool, mut trace: impl FnMut(f32) -> bool) -> Option<f32> {
    if trace(side) { Some(side) }
    else if retry && side != 0. && trace(-side) { Some(-side) }
    else { None }
}
/// `bot_defensive_tactics`: Stim/Phase as soon as health is low, instead of
/// only inside the shared 10-of-25-second request window. Readiness gating in
/// `Pulse` still applies, so an unavailable ability cannot hold the button.
pub(super) fn defensive_now(tactical: &str, health: i32) -> bool {
    matches!(tactical, "mp_ability_heal" | "mp_ability_shifter") && health > 0 && health < 60
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn toss_press_can_finish_pullout_but_still_releases_and_obeys_readiness() {
        let mut p = Pulse::default();
        assert!(p.press_for(1.,7,true,ready(1.),0.45,true));
        assert!(p.press_for(1.3,7,true,ready(1.3),0.45,true));
        assert!(!p.press_for(1.5,7,true,ready(1.5),0.45,true));
        assert!(!p.press_for(1.6,7,true,ready(1.6),0.45,true));
        assert_eq!(p.starts,1);
        assert!(p.press_for(2.1,7,true,ready(2.1),0.45,true));
        assert!(!p.press_for(2.2,7,true,None,0.45,true));
    }
    #[test] fn committed_busy_continuation_requires_fresh_matching_sample_and_expires() {
        let busy = |at, weapon| Some(Ready {at,weapon,ready:false});
        let mut p = Pulse::default();
        assert!(!p.press_for(0.9,7,true,busy(0.9,7),0.45,true));
        assert!(p.press_for(1.,7,true,ready(1.),0.45,true));
        assert!(p.press_for(1.2,7,true,busy(1.2,7),0.45,true));
        assert!(!p.press_for(1.5,7,true,busy(1.5,7),0.45,true));
        for sample in [None, busy(1.,7), busy(1.3,8)] {
            let mut q = Pulse::default();
            assert!(q.press_for(1.,7,true,ready(1.),0.45,true));
            assert!(!q.press_for(1.4,7,true,sample,0.45,true));
        }
    }
    #[test] fn defensive_tactics_only_for_stim_phase_when_hurt() {
        assert!(defensive_now("mp_ability_heal", 40)); assert!(defensive_now("mp_ability_shifter", 59));
        assert!(!defensive_now("mp_ability_heal", 60)); assert!(!defensive_now("mp_ability_heal", 0));
        assert!(!defensive_now("mp_ability_grapple", 10)); assert!(!defensive_now("mp_ability_cloak", 10));
    }
    fn ready(at: f32) -> Option<Ready> { Some(Ready { at, weapon: 7, ready: true }) }
    #[test] fn stale_future_wrong_weapon_and_unavailable_never_press() {
        for r in [None, ready(0.), ready(2.), Some(Ready {at: 1., weapon: 8, ready: true}), Some(Ready {at: 1.,weapon: 7,ready: false})] {
            assert!(!Pulse::default().press(1., 7, true, r));
        }
    }
    #[test] fn long_readiness_does_not_hold_a_button_or_retry_each_frame() {
        let mut p = Pulse::default();
        assert!(p.press(1., 7, true, ready(1.)));
        assert!(p.press(1.1, 7, true, ready(1.1)));
        assert!(!p.press(1.2, 7, true, ready(1.2)));
        assert!(!p.press(1.9, 7, true, ready(1.9)));
        assert!(p.press(2.01, 7, true, ready(2.01)));
        assert_eq!(p.starts, 2);
    }
    #[test] fn extended_interval_retains_short_press_and_readiness_safety() {
        let mut p = Pulse::default();
        assert!(p.press_with_interval(1., 7, true, ready(1.), 6.));
        assert!(p.press_with_interval(1.08, 7, true, ready(1.08), 6.));
        assert!(!p.press_with_interval(1.2, 7, true, ready(1.2), 6.));
        assert!(!p.press_with_interval(6.9, 7, true, ready(6.9), 6.));
        assert!(p.press_with_interval(7.01, 7, true, ready(7.01), 6.));
        assert_eq!(p.starts, 2);
        assert!(!p.press_with_interval(f32::NAN, 7, true, ready(1.), 6.));
        assert!(!p.press_with_interval(8., 7, true, ready(8.), 0.));
    }
    #[test] fn cooldown_consumption_releases_immediately() {
        let mut p = Pulse::default(); assert!(p.press(1., 7, true, ready(1.)));
        assert!(!p.press(1.02, 7, true, Some(Ready {at:1.02,weapon:7,ready:false})));
        assert!(!p.press(1.03, 7, false, ready(1.03)));
    }
    #[test] fn clock_reset_and_weapon_change_reset_pulse_state() {
        let mut p = Pulse::default(); assert!(p.press(10., 7, true, ready(10.)));
        assert!(p.press(1., 7, true, ready(1.)));
        assert!(p.press(1.01, 8, true, Some(Ready{at:1.01,weapon:8,ready:true})));
        assert!(!p.press(f32::NAN, 8, true, ready(1.)));
    }
    #[test] fn target_requires_fresh_explicit_landed_state() {
        assert!(eligible_target(1., Some((1., true))));
        for s in [None, Some((1., false)), Some((0., true)), Some((2., true)), Some((f32::NAN,true))] {
            assert!(!eligible_target(1., s));
        }
    }
    #[test] fn opposite_step_obeys_both_traces_and_feature_switch() {
        assert_eq!(clear_side(0.3, true, |_| true), Some(0.3));
        assert_eq!(clear_side(0.3, true, |side| side < 0.), Some(-0.3));
        assert_eq!(clear_side(0.3, true, |_| false), None);
        assert_eq!(clear_side(0.3, false, |side| side < 0.), None);
    }
}
