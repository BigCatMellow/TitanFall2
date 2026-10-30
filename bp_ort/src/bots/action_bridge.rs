use std::{cell::RefCell, collections::HashMap};
use once_cell::sync::Lazy;
use rrplug::{bindings::class_types::{cbaseentity::CBaseEntity, cplayer::CPlayer}, prelude::*};
use super::action_policy::{Ready, eligible_target};
use rrplug::high::vector::Vector3;
use super::frag_escape::Sample;

#[derive(Clone, Copy, Debug)]
pub(super) struct Readiness { pub tactical: Ready, pub ordnance: Ready }
#[derive(Default)]
struct Bridge { actors: HashMap<i32, Readiness>, targets: HashMap<i32, (f32, bool)>, frags: HashMap<(i32,i32),Sample> }
static DATA: EngineGlobal<Lazy<RefCell<Bridge>>> = EngineGlobal::new(Lazy::new(|| RefCell::new(Bridge::default())));
pub(super) fn register() {
    register_sq_functions(report_readiness);
    register_sq_functions(report_target);
    register_sq_functions(report_owned_frag);
}
pub(super) fn reset(token: EngineToken) { DATA.get(token).replace(Bridge::default()); }
pub(super) fn readiness(actor: i32, token: EngineToken) -> Option<Readiness> {
    DATA.get(token).try_borrow().ok()?.actors.get(&actor).copied()
}
pub(super) fn owned_frag(actor:i32,now:f32,origin:[f32;3],token:EngineToken)->Option<Sample>{
    DATA.get(token).try_borrow().ok()?.frags.iter().filter(|((owner,_),_)|*owner==actor)
        .filter_map(|(_,s)|s.danger_distance(now,origin).map(|distance|(*s,distance)))
        .min_by(|a,b|a.1.total_cmp(&b.1)).map(|(s,_)|s)
}
#[rrplug::sqfunction(VM = "SERVER", ExportName = "BotReportOwnedFrag")]
fn report_owned_frag(bot:Option<&mut CPlayer>,projectile:Option<&mut CBaseEntity>,position:Vector3,velocity:Vector3,age:f32,at:f32)->Option<()> {
    if !at.is_finite() || !age.is_finite() || age<0. || age>6.
        || ![position.x,position.y,position.z,velocity.x,velocity.y,velocity.z].iter().all(|v|v.is_finite()){return None;}
    let bot=bot?;let actor=bot.m_RefEHandle;let owner_velocity=bot.m_vecAbsVelocity;
    let id=projectile?.m_RefEHandle;
    if actor == -1 || id == -1 {return None;}
    let mut data=DATA.get(engine_token).try_borrow_mut().ok()?;
    data.frags.retain(|_,s|s.at<=at&&at-s.at<=0.35);
    if data.frags.len()>=128 && !data.frags.contains_key(&(actor,id)){return None;}
    data.frags.insert((actor,id),Sample::observed(id,at,age,[position.x,position.y,position.z],
        [velocity.x,velocity.y,velocity.z],[owner_velocity.x,owner_velocity.y,owner_velocity.z]));
    Some(())
}
pub(super) fn target_allowed(target: i32, now: f32, token: EngineToken) -> bool {
    let sample = DATA.get(token).try_borrow().ok().and_then(|data| data.targets.get(&target).copied());
    eligible_target(now, sample)
}
#[rrplug::sqfunction(VM = "SERVER", ExportName = "BotReportReadiness")]
fn report_readiness(bot: Option<&mut CPlayer>, tactical: Option<&mut CBaseEntity>, tactical_ready: bool,
    ordnance: Option<&mut CBaseEntity>, ordnance_ready: bool, at: f32) -> Option<()> {
    if !at.is_finite() { return None; }
    let actor = bot?.m_RefEHandle;
    let mut data = DATA.get(engine_token).try_borrow_mut().ok()?;
    // Bound stale entity accumulation across disconnect/reconnects within a map.
    data.actors.retain(|_, r| r.tactical.at <= at && at - r.tactical.at < 2.);
    data.actors.insert(actor, Readiness {
        tactical: Ready {at, weapon: tactical.map_or(-1, |w| w.m_RefEHandle), ready: tactical_ready},
        ordnance: Ready {at, weapon: ordnance.map_or(-1, |w| w.m_RefEHandle), ready: ordnance_ready},
    });
    Some(())
}
#[rrplug::sqfunction(VM = "SERVER", ExportName = "BotReportTargetEligibility")]
fn report_target(target: Option<&mut CBaseEntity>, eligible: bool, at: f32) -> Option<()> {
    if !at.is_finite() { return None; }
    let id = target?.m_RefEHandle;
    let mut data = DATA.get(engine_token).try_borrow_mut().ok()?;
    data.targets.retain(|_, (last, _)| *last <= at && at - *last < 2.);
    if data.targets.get(&id).is_none_or(|(_, old)| *old != eligible) {
        log::info!("BOT_TARGET_STATE epoch={} t={at:.2} id={id} eligible={}", super::telemetry::epoch(), eligible as u8);
    }
    data.targets.insert(id, (at, eligible));
    Some(())
}
