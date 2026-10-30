//! Default-off owned-frag escape. Samples are actual projectiles, not throw intent.
#[derive(Clone,Copy,Debug)]
pub(super) struct Sample {pub id:i32,pub at:f32,pub age:f32,pub pos:[f32;3],pub velocity:[f32;3]}
impl Sample {
    pub fn observed(id:i32,at:f32,age:f32,pos:[f32;3],projectile_velocity:[f32;3],owner_velocity:[f32;3])->Self{
        Self{id,at,age,pos,velocity:std::array::from_fn(|i|projectile_velocity[i]-owner_velocity[i])}
    }
    pub fn danger_distance(self,now:f32,origin:[f32;3])->Option<f32>{
        let distance=self.proximity_distance(now,origin)?;
        if distance>320. {return None;}
        let d=[self.pos[0]-origin[0],self.pos[1]-origin[1]];
        // Relative departure suppresses entry, never an escape already underway.
        if distance>1. && (self.velocity[0]*d[0]+self.velocity[1]*d[1])/distance>200. {return None;}
        Some(distance)
    }
    pub fn proximity_distance(self,now:f32,origin:[f32;3])->Option<f32>{
        if self.id == -1 || !now.is_finite() || !self.at.is_finite() || now<self.at || now-self.at>0.25
            || !self.age.is_finite() || !(0.35..=6.).contains(&(self.age+now-self.at))
            || !origin.iter().chain(self.pos.iter()).chain(self.velocity.iter()).all(|v|v.is_finite()) {return None;}
        let d=[self.pos[0]-origin[0],self.pos[1]-origin[1]];let distance=d[0].hypot(d[1]);
        if distance>352. || (self.pos[2]-origin[2]).abs()>96. {return None;}
        Some(distance)
    }
}
#[derive(Debug,Default)]
pub(super) struct FragEscape {
    next_probe:f32,last_time:f32,projectile:Option<i32>,heading:Option<f32>,began:Option<f32>,retry_after:f32,
    pub probes:u32,pub starts:u32,pub blocked:u32,
}
impl FragEscape {
    pub fn active(&self)->bool{self.heading.is_some()}
    pub fn tracked(&self)->Option<i32>{if self.active(){self.projectile}else{None}}
    pub fn cancel(&mut self){self.heading=None;self.began=None;self.projectile=None;}
    /// At most three checked, separation-increasing ground moves every0.2s.
    /// Commands are world bearings; the caller preserves aim and reframes input.
    pub fn update(&mut self,now:f32,origin:[f32;3],aim_yaw:f32,sample:Option<Sample>,allowed:bool,
        mut clear:impl FnMut(f32)->bool)->Option<f32>{
        if !now.is_finite() || now<self.last_time {*self=Self::default();if !now.is_finite(){return None;}}
        self.last_time=now;
        let Some(s)=sample.filter(|s|allowed&&aim_yaw.is_finite()&&
            if self.tracked()==Some(s.id){s.proximity_distance(now,origin).is_some()}
            else{s.danger_distance(now,origin).is_some()}) else {self.cancel();return None;};
        if now<self.retry_after {self.cancel();return None;}
        if self.projectile!=Some(s.id){self.cancel();self.projectile=Some(s.id);self.next_probe=now;}
        if self.began.is_some_and(|at|now-at>=2.){self.cancel();self.retry_after=now+0.35;return None;}
        if now<self.next_probe{return self.heading;}
        self.next_probe=now+0.2;self.probes=self.probes.saturating_add(1);
        let dx=origin[0]-s.pos[0];let dy=origin[1]-s.pos[1];let distance=dx.hypot(dy);
        let away=if distance>1.{dy.atan2(dx).to_degrees()}else{aim_yaw+180.};
        let was_active=self.active();self.heading=None;
        for offset in [0.,60.,-60.]{
            let yaw=away+offset;let (sn,cs)=yaw.to_radians().sin_cos();
            if (dx+cs*64.).hypot(dy+sn*64.)-distance<8. {continue;}
            if clear(yaw){self.heading=Some(yaw);break;}
        }
        if self.active(){if !was_active{self.starts=self.starts.saturating_add(1);}self.began.get_or_insert(now);}
        else {self.blocked=self.blocked.saturating_add(1);self.began=None;}
        self.heading
    }
}
#[cfg(test)] mod tests{
    use super::*;
    fn frag(at:f32)->Sample{Sample{id:7,at,age:1.,pos:[100.,0.,0.],velocity:[0.;3]}}
    #[test] fn owner_chasing_a_grenade_is_not_mistaken_for_a_fast_safe_departure(){
        let chased=Sample::observed(7,1.,1.,[100.,0.,0.],[300.,0.,0.],[260.,0.,0.]);
        assert!(chased.danger_distance(1.,[0.;3]).is_some());
        let departing=Sample::observed(7,1.,1.,[100.,0.,0.],[700.,0.,0.],[260.,0.,0.]);
        assert!(departing.danger_distance(1.,[0.;3]).is_none());
    }
    #[test] fn active_escape_ignores_its_own_departure_velocity_and_uses_exit_hysteresis(){
        let mut a=FragEscape::default();
        assert!(a.update(1.,[0.;3],0.,Some(frag(1.)),true,|_|true).is_some());
        let departing=Sample{velocity:[300.,0.,0.],..frag(1.1)};
        assert!(departing.danger_distance(1.1,[0.;3]).is_none());
        assert!(a.update(1.1,[0.;3],0.,Some(departing),true,|_|panic!("cached")).is_some());
        let edge=Sample{pos:[330.,0.,0.],..frag(1.3)};
        assert!(edge.danger_distance(1.3,[0.;3]).is_none());
        assert!(a.update(1.3,[0.;3],0.,Some(edge),true,|_|true).is_some());
        assert_eq!(a.starts,1);
        assert!(a.update(1.5,[0.;3],0.,Some(Sample{pos:[353.,0.,0.],..frag(1.5)}),true,|_|panic!("safe")).is_none());
        assert!(a.update(1.6,[0.;3],0.,Some(Sample{at:1.6,..edge}),true,|_|panic!("entry range")).is_none());
    }
    #[test] fn sensor_requires_actual_fresh_nearby_same_floor_released_projectile(){
        assert_eq!(frag(1.).danger_distance(1.,[0.;3]),Some(100.));
        for s in [Sample{age:0.,..frag(1.)},Sample{at:0.5,..frag(1.)},Sample{pos:[100.,0.,100.],..frag(1.)},Sample{pos:[321.,0.,0.],..frag(1.)},Sample{velocity:[500.,0.,0.],..frag(1.)},Sample{id:-1,..frag(1.)}]{assert_eq!(s.danger_distance(1.,[0.;3]),None);}
        assert!(Sample{id:-500,..frag(1.)}.danger_distance(1.,[0.;3]).is_some());
        assert!(Sample{velocity:[-500.,0.,0.],..frag(1.)}.danger_distance(1.,[0.;3]).is_some());
    }
    #[test] fn moves_away_or_checked_side_never_toward_and_limits_trace_budget(){
        let mut a=FragEscape::default();let mut checked=vec![];
        let yaw=a.update(1.,[0.;3],0.,Some(frag(1.)),true,|yaw|{checked.push(yaw);checked.len()==2}).unwrap();
        assert_eq!(checked.len(),2);assert!(yaw.to_radians().cos()<0.);
        assert_eq!(a.update(1.1,[0.;3],90.,Some(frag(1.1)),true,|_|panic!("cached")),Some(yaw));
        assert_eq!(a.probes,1);
    }
    #[test] fn no_checked_escape_does_not_invent_a_move_or_retry_each_frame(){
        let mut a=FragEscape::default();let mut probes=0;
        assert_eq!(a.update(1.,[0.;3],0.,Some(frag(1.)),true,|_|{probes+=1;false}),None);assert_eq!(probes,3);
        assert_eq!(a.update(1.1,[0.;3],0.,Some(frag(1.1)),true,|_|panic!("throttled")),None);assert_eq!(a.blocked,1);
    }
    #[test] fn disable_stale_sensor_jump_handoff_and_clock_reset_release(){
        let mut a=FragEscape::default();a.update(1.,[0.;3],0.,Some(frag(1.)),true,|_|true);
        assert!(a.active());assert_eq!(a.update(1.1,[0.;3],0.,Some(frag(1.1)),false,|_|panic!("disabled")),None);assert!(!a.active());
        a.update(2.,[0.;3],0.,Some(frag(2.)),true,|_|true);
        assert_eq!(a.update(2.3,[0.;3],0.,Some(frag(2.)),true,|_|panic!("stale")),None);
        assert_eq!(a.update(0.,[0.;3],0.,None,true,|_|panic!("reset")),None);assert!(!a.active());
    }
    #[test] fn action_is_bounded_and_a_changed_projectile_invalidates_cached_heading(){
        let mut a=FragEscape::default();a.update(1.,[0.;3],0.,Some(frag(1.)),true,|_|true);
        assert_eq!(a.update(3.,[0.;3],0.,Some(frag(3.)),true,|_|panic!("expired")),None);
        assert_eq!(a.update(3.1,[0.;3],0.,Some(frag(3.1)),true,|_|panic!("cooldown")),None);
        assert!(a.update(3.4,[0.;3],0.,Some(frag(3.4)),true,|_|true).is_some());
        let mut probed=false;assert!(a.update(3.41,[0.;3],0.,Some(Sample{id:9,..frag(3.41)}),true,|_|{probed=true;true}).is_some());assert!(probed);
    }
}
