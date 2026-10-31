//! Per-bot knowledge. Only confirmed visible observations enter this memory.
//! No hidden-position updates, team knowledge propagation, sound or radar claims.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) struct Seen { pub id:i32, pub pos:[f32;3], pub at:f32 }
#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) struct Goal { pub seen:Seen, pub search:bool }
#[derive(Clone, Copy, Debug)]
struct Entry { seen:Seen, arrived:Option<f32> }
#[derive(Debug, Default)]
pub(super) struct Memory { entries:[Option<Entry>;8], last:Option<f32> }
impl Memory {
 pub fn update(&mut self,now:f32,origin:[f32;3],visible:Option<Seen>,live:&[i32],seconds:f32)->Option<Goal>{
  if !now.is_finite()||origin.iter().any(|v|!v.is_finite()) { *self=Self::default();return None; }
  if self.last.is_some_and(|t|now<t){*self=Self::default();}
  self.last=Some(now);
  let seconds=if seconds.is_finite(){seconds.clamp(1.,12.)}else{4.};
  for slot in &mut self.entries {if slot.is_some_and(|e|!live.contains(&e.seen.id)||now<e.seen.at||now-e.seen.at>seconds||e.arrived.is_some_and(|t|now-t>=1.5)){*slot=None;}}
  if let Some(v)=visible.filter(|v|v.id!=-1&&live.contains(&v.id)&&v.pos.iter().all(|p|p.is_finite())){
   let slot=self.entries.iter().position(|e|e.is_some_and(|e|e.seen.id==v.id))
    .or_else(||self.entries.iter().position(Option::is_none))
    .unwrap_or_else(||self.entries.iter().enumerate().min_by(|(_,a),(_,b)|a.unwrap().seen.at.total_cmp(&b.unwrap().seen.at)).map_or(0,|(i,_)|i));
   let seen=Seen{at:now,..v};self.entries[slot]=Some(Entry{seen,arrived:None});return Some(Goal{seen,search:false});
  }
  let slot=self.entries.iter().enumerate().filter_map(|(i,e)|e.map(|e|(i,e.seen.at))).max_by(|a,b|a.1.total_cmp(&b.1)).map(|(i,_)|i)?;
  let e=self.entries[slot].as_mut()?;
  if (origin[0]-e.seen.pos[0]).hypot(origin[1]-e.seen.pos[1])<=100.&&(origin[2]-e.seen.pos[2]).abs()<=100.{e.arrived.get_or_insert(now);}
  Some(Goal{seen:e.seen,search:e.arrived.is_some()})
 }
}
#[derive(Debug, Default)]
pub(super) struct Patrol { goal:Option<([f32;3],f32)>, next:f32, last:Option<f32> }
impl Patrol {
 pub fn goal(&mut self,now:f32,origin:[f32;3])->Option<[f32;3]>{
  if !now.is_finite()||origin.iter().any(|x|!x.is_finite())||self.last.is_some_and(|t|now<t){*self=Self::default();return None;}
  self.last=Some(now);
  if self.goal.is_some_and(|(p,until)|now>=until||(origin[0]-p[0]).hypot(origin[1]-p[1])<100.){self.goal=None;}
  self.goal.map(|(p,_)|p)
 }
 pub fn can_pick(&self,now:f32)->bool{now.is_finite()&&self.goal.is_none()&&now>=self.next}
 pub fn pick(&mut self,now:f32,point:Option<[f32;3]>){self.next=now+2.;self.goal=point.filter(|p|p.iter().all(|v|v.is_finite())).map(|p|(p,now+8.));}
}
#[cfg(test)] mod tests {
 use super::*;
 fn seen(id:i32,x:f32)->Seen{Seen{id,pos:[x,0.,0.],at:0.}}
 #[test]fn never_seen_is_not_known(){assert_eq!(Memory::default().update(1.,[0.;3],None,&[1],4.),None);}
 #[test]fn hidden_target_does_not_update_position(){let mut m=Memory::default();m.update(1.,[0.;3],Some(seen(1,500.)),&[1],4.);assert_eq!(m.update(3.,[0.;3],None,&[1],4.).unwrap().seen.pos,[500.,0.,0.]);}
 #[test]fn expires_without_refresh(){let mut m=Memory::default();m.update(1.,[0.;3],Some(seen(1,500.)),&[1],2.);assert!(m.update(3.01,[0.;3],None,&[1],2.).is_none());}
 #[test]fn visible_reacquisition_refreshes(){let mut m=Memory::default();m.update(1.,[0.;3],Some(seen(1,500.)),&[1],4.);m.update(4.,[0.;3],Some(seen(1,900.)),&[1],4.);assert_eq!(m.update(7.,[0.;3],None,&[1],4.).unwrap().seen.pos[0],900.);}
 #[test]fn death_and_clock_rollback_clear(){let mut m=Memory::default();m.update(3.,[0.;3],Some(seen(1,500.)),&[1],4.);assert!(m.update(4.,[0.;3],None,&[],4.).is_none());m.update(5.,[0.;3],Some(seen(1,500.)),&[1],4.);assert!(m.update(1.,[0.;3],None,&[1],4.).is_none());}
 #[test]fn brief_search_then_forget(){let mut m=Memory::default();m.update(1.,[0.;3],Some(seen(1,500.)),&[1],10.);assert!(m.update(2.,[500.,0.,0.],None,&[1],10.).unwrap().search);assert!(m.update(3.6,[500.,0.,0.],None,&[1],10.).is_none());}
 #[test]fn bounded_history_remembers_others(){let mut m=Memory::default();let live:Vec<_>=(1..=10).collect();for i in 1..=10{m.update(i as f32,[0.;3],Some(seen(i,500.)),&live,12.);}assert_eq!(m.entries.iter().flatten().count(),8);assert_eq!(m.update(10.1,[0.;3],None,&[9],12.).unwrap().seen.id,9);}
 #[test]fn patrol_expires_and_throttles_failed_queries(){let mut p=Patrol::default();assert!(p.can_pick(1.));p.pick(1.,None);assert!(!p.can_pick(2.));p.pick(3.,Some([500.,0.,0.]));assert_eq!(p.goal(4.,[0.;3]),Some([500.,0.,0.]));assert!(p.goal(11.,[0.;3]).is_none());assert!(p.can_pick(11.));}
}
