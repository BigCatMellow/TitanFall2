//! Experimental ownership of a known type16 short-jump segment. No physics,
//! teleportation or aim-power changes. Failure hands back to bounded recovery.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum Failure { InvalidInput, LostEntry, ApproachTimeout, NoLift, EarlyLanding, NoProgress, Timeout }
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Phase { Approach, FirstPress, Flight, SecondPress, Landing }
#[derive(Debug, Clone, Copy)]
struct Commit {
    entry: [f32;3], exit: [f32;3], began: f32, phase: Phase, first_press: f32,
    airborne: Option<f32>, second_until: f32, best_distance: f32, progress_at: f32,
}
#[derive(Debug, Default)]
pub(super) struct TraversalAction { commit: Option<Commit>, retry_after: f32 }
#[derive(Debug, Clone, Copy)]
pub(super) struct Input { pub now:f32, pub origin:[f32;3], pub velocity:[f32;2], pub grounded:bool, pub facing_error:f32 }
#[derive(Debug, Clone, Copy, PartialEq)]
pub(super) enum Step {
    Idle,
    Active { jump:bool, forward:bool },
    Completed,
    Failed(Failure),
}
fn xy(a:[f32;3],b:[f32;3])->f32 {(a[0]-b[0]).hypot(a[1]-b[1])}
fn finite(p:[f32;3])->bool {p.iter().all(|v|v.is_finite())}
impl TraversalAction {
    pub fn active(&self)->bool {self.commit.is_some()}
    pub fn phase_label(&self)->&'static str {
        self.commit.map_or("idle",|c|match c.phase {
            Phase::Approach=>"approach",Phase::FirstPress=>"first_press",Phase::Flight=>"flight",
            Phase::SecondPress=>"second_press",Phase::Landing=>"landing",
        })
    }
    pub fn cancel(&mut self) {self.commit=None;}
    /// Approach the entry while turning toward the exit; after takeoff keep
    /// the exit as the movement goal. Never synthesize or increase velocity.
    pub fn movement_goal(&self,origin:[f32;3])->Option<[f32;3]> {
        self.commit.map(|c|if c.phase==Phase::Approach&&xy(origin,c.entry)>32. {c.entry}else{c.exit})
    }
    pub fn exit(&self)->Option<[f32;3]> {self.commit.map(|c|c.exit)}
    pub fn can_begin(&self,now:f32,kind:u8,entry:[f32;3],exit:[f32;3],origin:[f32;3])->bool {
        if self.active()||kind!=16||!now.is_finite()||now<self.retry_after
            ||!finite(entry)||!finite(exit)||!finite(origin) {return false;}
        let length=xy(entry,exit);
        if !(64. ..=512.).contains(&length)||xy(origin,entry)>160.
            ||!(-72. ..=128.).contains(&(exit[2]-entry[2])) {return false;}
        true
    }
    pub fn begin(&mut self,now:f32,kind:u8,entry:[f32;3],exit:[f32;3],origin:[f32;3])->bool {
        if !self.can_begin(now,kind,entry,exit,origin) {return false;}
        self.commit=Some(Commit {entry,exit,began:now,phase:Phase::Approach,first_press:now,
            airborne:None,second_until:now,best_distance:xy(origin,exit),progress_at:now});
        true
    }
    pub fn step(&mut self,input:Input)->Step {
        let Some(mut c)=self.commit else {return Step::Idle;};
        let result=if !input.now.is_finite()||input.now<c.began||!finite(input.origin)||!input.facing_error.is_finite()
            ||!input.velocity.iter().all(|v|v.is_finite()) {
            Step::Failed(Failure::InvalidInput)
        }else if input.now-c.began>3.5 {
            Step::Failed(Failure::Timeout)
        }else if c.phase!=Phase::Approach&&input.grounded&&xy(input.origin,c.exit)<=45.
            &&(input.origin[2]-c.exit[2]).abs()<=40. {
            Step::Completed
        }else {
            let distance=xy(input.origin,c.exit);
            if c.best_distance-distance>=16. {c.best_distance=distance;c.progress_at=input.now;}
            match c.phase {
                Phase::Approach=>{
                    let length=xy(c.entry,c.exit);
                    let speed=(input.velocity[0]*(c.exit[0]-c.entry[0])+input.velocity[1]*(c.exit[1]-c.entry[1]))/length;
                    let minimum=if length>192. {180.}else{100.};
                    if xy(input.origin,c.entry)>192. {Step::Failed(Failure::LostEntry)}
                    else if input.grounded&&xy(input.origin,c.entry)<=48.&&input.facing_error.abs()<=20.
                        &&(input.origin[2]-c.entry[2]).abs()<=40.&&speed>=minimum {
                        c.phase=Phase::FirstPress;c.first_press=input.now;c.progress_at=input.now;
                        Step::Active {jump:true,forward:true}
                    }else if input.now-c.began>1.2 {Step::Failed(Failure::ApproachTimeout)}
                    else {Step::Active {jump:false,forward:true}}
                }
                _=>{
                    if !input.grounded&&c.airborne.is_none(){c.airborne=Some(input.now);}
                    if input.now-c.first_press>0.3&&c.airborne.is_none() {
                        Step::Failed(Failure::NoLift)
                    }else if input.grounded&&c.airborne.is_some_and(|at|input.now-at>0.12) {
                        Step::Failed(Failure::EarlyLanding)
                    }else if input.now-c.progress_at>1.2 {
                        Step::Failed(Failure::NoProgress)
                    }else if input.now-c.first_press<0.06 {
                        Step::Active {jump:true,forward:true}
                    }else {
                        if c.phase==Phase::FirstPress {c.phase=Phase::Flight;}
                        if c.phase==Phase::Flight&&c.airborne.is_some_and(|at|input.now-at>=0.18) {
                            c.phase=Phase::SecondPress;c.second_until=input.now+0.06;
                        }
                        if c.phase==Phase::SecondPress&&input.now>=c.second_until {c.phase=Phase::Landing;}
                        Step::Active {jump:c.phase==Phase::SecondPress,forward:true}
                    }
                }
            }
        };
        match result {
            Step::Active {..}=>self.commit=Some(c),
            Step::Failed(_)=>{self.commit=None;self.retry_after=if input.now.is_finite(){input.now+1.2}else{0.};},
            _=>self.commit=None,
        }
        result
    }
}

#[cfg(test)] mod tests {
    use super::*;
    fn input(now:f32,grounded:bool,x:f32,z:f32)->Input {Input {now,grounded,origin:[x,0.,z],velocity:[250.,0.],facing_error:0.}}
    fn action()->TraversalAction {let mut a=TraversalAction::default();assert!(a.begin(0.,16,[0.;3],[350.,0.,80.],[0.;3]));a}
    #[test] fn aligns_and_commits_exactly_two_released_presses_before_grounded_arrival() {
        let mut a=action();let mut i=input(0.,true,0.,0.);i.facing_error=90.;
        assert_eq!(a.step(i),Step::Active {jump:false,forward:true});
        assert_eq!(a.step(input(0.1,true,0.,0.)),Step::Active {jump:true,forward:true});
        assert_eq!(a.step(input(0.13,false,10.,25.)),Step::Active {jump:true,forward:true});
        assert_eq!(a.step(input(0.2,false,40.,60.)),Step::Active {jump:false,forward:true});
        assert_eq!(a.step(input(0.32,false,80.,65.)),Step::Active {jump:true,forward:true});
        assert_eq!(a.step(input(0.4,false,120.,100.)),Step::Active {jump:false,forward:true});
        assert_eq!(a.step(input(0.8,false,340.,150.)),Step::Active {jump:false,forward:true});
        assert_eq!(a.step(input(1.,true,350.,80.)),Step::Completed);assert!(!a.active());
    }
    #[test] fn blocks_unverified_types_and_unreachable_entry_or_geometry() {
        for kind in [0,1,2,8,255] {assert!(!TraversalAction::default().begin(0.,kind,[0.;3],[350.,0.,80.],[0.;3]));}
        assert!(!TraversalAction::default().begin(0.,16,[0.;3],[600.,0.,80.],[0.;3]));
        assert!(!TraversalAction::default().begin(0.,16,[0.;3],[350.,0.,200.],[0.;3]));
        assert!(!TraversalAction::default().begin(0.,16,[0.;3],[350.,0.,80.],[161.,0.,0.]));
    }
    #[test] fn no_surface_no_lift_and_clock_reset_release_ownership() {
        let mut a=action();assert!(matches!(a.step(input(1.21,false,0.,0.)),Step::Failed(Failure::ApproachTimeout)));
        assert!(!a.begin(1.3,16,[0.;3],[350.,0.,80.],[0.;3]));
        let mut a=action();a.step(input(0.,true,0.,0.));assert_eq!(a.step(input(0.31,true,0.,0.)),Step::Failed(Failure::NoLift));
        let mut a=action();assert_eq!(a.step(input(-1.,false,0.,0.)),Step::Failed(Failure::InvalidInput));
        let mut a=action();assert_eq!(a.step(input(0.1,true,193.,0.)),Step::Failed(Failure::LostEntry));
    }
    #[test] fn expiry_progress_failure_and_early_landing_do_not_loop_or_teleport() {
        let mut a=action();assert_eq!(a.step(input(3.51,false,0.,0.)),Step::Failed(Failure::Timeout));
        let mut a=action();a.step(input(0.,true,0.,0.));a.step(input(0.03,false,0.,20.));
        assert_eq!(a.step(input(1.21,false,0.,30.)),Step::Failed(Failure::NoProgress));
        let mut a=action();a.step(input(0.,true,0.,0.));a.step(input(0.03,false,10.,20.));
        assert_eq!(a.step(input(0.3,true,10.,0.)),Step::Failed(Failure::EarlyLanding));
        let mut a=action();a.cancel();assert_eq!(a.step(input(0.,true,0.,0.)),Step::Idle);
    }
    #[test] fn approach_retains_runup_but_requires_ground_heading_and_forward_momentum() {
        let mut a=TraversalAction::default();
        assert!(a.begin(0.,16,[0.;3],[350.,0.,80.],[-150.,0.,0.]));
        assert_eq!(a.movement_goal([-150.,0.,0.]),Some([0.;3]));
        assert_eq!(a.step(input(0.,true,-150.,0.)),Step::Active {jump:false,forward:true});
        for velocity in [[0.,0.],[-250.,0.],[0.,300.],[179.,0.]] {
            let mut i=input(0.2,true,-25.,0.);i.velocity=velocity;
            assert_eq!(a.step(i),Step::Active {jump:false,forward:true});
        }
        assert_eq!(a.movement_goal([-25.,0.,0.]),Some([350.,0.,80.]));
        assert_eq!(a.step(input(0.3,true,-25.,0.)),Step::Active {jump:true,forward:true});
        assert_eq!(a.movement_goal([-25.,0.,20.]),Some([350.,0.,80.]));
    }
    #[test] fn invalid_velocity_releases_and_never_turns_waiting_into_fake_completion() {
        let mut a=action();let mut i=input(0.,true,0.,0.);i.velocity=[f32::NAN,0.];
        assert_eq!(a.step(i),Step::Failed(Failure::InvalidInput));assert!(!a.active());
        let mut a=action();assert_eq!(a.step(input(0.1,true,350.,80.)),Step::Failed(Failure::LostEntry));
    }
}
