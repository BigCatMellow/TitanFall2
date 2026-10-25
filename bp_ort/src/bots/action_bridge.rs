use std::{cell::RefCell, collections::HashMap};
use once_cell::sync::Lazy;
use rrplug::{bindings::class_types::{cbaseentity::CBaseEntity, cplayer::CPlayer}, prelude::*};
use super::action_policy::{Ready, eligible_target};

#[derive(Clone, Copy, Debug)]
pub(super) struct Readiness { pub tactical: Ready, pub ordnance: Ready }
#[derive(Default)]
struct Bridge { actors: HashMap<i32, Readiness>, targets: HashMap<i32, (f32, bool)> }
static DATA: EngineGlobal<Lazy<RefCell<Bridge>>> = EngineGlobal::new(Lazy::new(|| RefCell::new(Bridge::default())));
pub(super) fn register() {
    register_sq_functions(report_readiness);
    register_sq_functions(report_target);
}
pub(super) fn reset(token: EngineToken) { DATA.get(token).replace(Bridge::default()); }
pub(super) fn readiness(actor: i32, token: EngineToken) -> Option<Readiness> {
    DATA.get(token).try_borrow().ok()?.actors.get(&actor).copied()
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
