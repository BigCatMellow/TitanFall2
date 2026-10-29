use itertools::Itertools;
use rrplug::{
    bindings::class_types::{cbaseentity::CBaseEntity, cplayer::CPlayer},
    high::vector::Vector3,
};
use shared::utils::{get_player_index, nudge_type};
use std::mem::MaybeUninit;

use crate::{
    bindings::{Action, CGameTrace, CTraceFilterSimple, CUserCmd, Ray, VectorAligned},
    interfaces::ENGINE_INTERFACES,
    navmesh::RECAST_DETOUR,
};

use super::{BotData, cmds_helper::CUserCmdHelper};

pub(super) const GROUND_OFFSET: Vector3 = Vector3::new(0., 0., 20.);
pub(super) const BOT_VISON_RANGE: f32 = 3000.;
pub(super) const BOT_PATH_NODE_RANGE: f32 = 45.;
pub(super) const BOT_PATH_RECAL_RANGE: f32 = 600.;

pub fn look_at(origin: Vector3, target: Vector3) -> Vector3 {
    let diff = target - origin;
    let angley = diff.y.atan2(diff.x).to_degrees();
    let anglex = diff
        .z
        .atan2((diff.x.powi(2) + diff.y.powi(2)).sqrt())
        .to_degrees();

    Vector3::new(-anglex, angley, 0.)
}

pub fn path_to_target(
    cmd: &mut CUserCmd,
    local_data: &mut BotData,
    origin: Vector3,
    target_pos: Vector3,
    should_recalcute_path: bool,
    helper: &CUserCmdHelper,
) -> bool {
    local_data.navigation_requested = true;
    let eden_repair=eden_repair_active(helper)
        && local_data.nav_query.as_ref().is_some_and(|n|n.hull==crate::navmesh::Hull::Human);
    if distance3(target_pos, origin)
        <= BOT_PATH_NODE_RANGE + local_data.approach_range.unwrap_or(20.) {
        local_data.movement_anchor = None;
        return false;
    }
    if time(helper) < local_data.recovery_until {
        face_toward(cmd, origin, target_pos, helper);
        try_avoid_obstacle(cmd, local_data, helper);
        return true;
    }
    if super::progress_watchdog::has_stalled(time(helper), &mut local_data.movement_anchor,
        [origin.x, origin.y]) {
        note_failed_link(local_data, origin, helper, "no_progress");
        if let Some(nav) = local_data.nav_query.as_mut() {
            nav.path_points.clear();
            nav.end_point = None;
        }
        local_data.recovery_until = time(helper) + 1.2;
        local_data.stall_event = Some("no_progress");
        note_stalled_pursuit(local_data, helper, "no_progress");
        note_recovery(local_data, origin, helper, "no_progress");
        face_toward(cmd, origin, target_pos, helper);
        try_avoid_obstacle(cmd, local_data, helper);
        return true;
    }
    let dt_funcs = RECAST_DETOUR.wait();
    let debug = ENGINE_INTERFACES.wait().debug_overlay;
    let Some(nav) = local_data.nav_query.as_mut() else {
        log::warn!("null nav");
        return false;
    };

    _ = nav
        .path_points
        .last()
        .map(|point| unsafe { debug.AddLineOverlay(&origin, point, 0, 255, 0, true, 0.1) });
    nav.path_points
        .iter()
        .cloned()
        .tuple_windows()
        .for_each(|(p1, p2)| unsafe { debug.AddLineOverlay(&p1, &p2, 0, 255, 0, true, 0.5) });
    _ = nav
        .path_points
        .last()
        .map(|point| unsafe { debug.AddLineOverlay(point, &target_pos, 0, 255, 0, true, 0.1) });

    let must_replan = nav
        .end_point
        .map(|point| distance(point, target_pos) > BOT_PATH_RECAL_RANGE)
        .map(|should_recalculate| should_recalculate || should_recalcute_path)
        .unwrap_or(true);
    let pending_waypoint = super::route_guard::active_waypoint_pending(
        super::switch_on(&super::ROUTE_CONTINUITY_CONVAR) || eden_repair, !must_replan,
        local_data.current_corner.is_some(), distance(local_data.next_target_pos, origin),
        BOT_PATH_NODE_RANGE);
    let segment_consumed = nav.path_points.is_empty() && !pending_waypoint;
    if pending_waypoint && nav.path_points.is_empty()
        && super::switch_on(&super::NAV_DIAGNOSTICS_CONVAR)
        && local_data.segment_log.allow(time(helper), 1.) {
        log::info!("BOT_SEGMENT epoch={} t={:.2} slot={} event=finish_pending dist={:.1} dz={:.1} x={:.1} y={:.1} z={:.1}",
            super::telemetry::epoch(),time(helper),local_data.edict,
            distance(local_data.next_target_pos,origin),local_data.next_target_pos.z-origin.z,
            origin.x,origin.y,origin.z);
    }
    if !must_replan && segment_consumed
        && super::switch_on(&super::ROUTE_GUARD_CONVAR)
        && !local_data.replan.allow_consumed_replan(time(helper))
    {
        // A consumed partial route ends where the mesh stops; requesting the
        // same route every frame only spins in place. Hold briefly instead.
        face_toward(cmd, origin, target_pos, helper);
        return true;
    }
    if must_replan || segment_consumed
    {
        if let Some(since) = local_data.corner_guard_since.take() {
            log::info!("BOT_CORNER_GUARD epoch={} t={:.2} slot={} event=end reason=replan held_s={:.2}",
                super::telemetry::epoch(),time(helper),local_data.edict,(time(helper)-since).max(0.));
        }
        local_data.last_time_node_reached = helper.globals.curTime;
        local_data.next_target_pos = origin;
        // A replanned corridor has not yet produced a matching next-corner.
        // Do not let diagnostics or low-clearance actions reuse stale metadata.
        local_data.current_corner = None;

        // this might be the reason of the sudden aim shift or not really idk
        if local_data.last_bad_path + 1. >= helper.globals.curTime {
            face_toward(cmd, origin, target_pos, helper);
            try_avoid_obstacle(cmd, local_data, helper);

            return false;
        }

        local_data.metrics.path_requests = local_data.metrics.path_requests.saturating_add(1);
        let original_traversals = nav.filter.m_traverseFlags;
        let excluded = if (super::switch_on(&super::LINK_DETOUR_CONVAR) || eden_repair) && nav.hull==crate::navmesh::Hull::Human {
            local_data.link_detour.excluded(time(helper),[origin.x,origin.y])
        } else {0};
        nav.filter.m_traverseFlags &= !excluded;
        let result = nav.new_path(origin, target_pos, dt_funcs);
        nav.filter.m_traverseFlags = original_traversals;
        let status = nav.last_status;
        let partial = super::nav_diagnostics::is_partial(status);
        let end_gap = nav.last_end.map_or(f32::INFINITY, |end| distance3(end, target_pos));
        local_data.replan.note_plan(time(helper), partial);
        if result.is_ok() && let Some(id) = local_data.route_target {
            local_data.unreachable.note(time(helper), id, partial, end_gap);
        }
        if super::switch_on(&super::NAV_DIAGNOSTICS_CONVAR)
            && local_data.path_log.allow(time(helper), 1.) {
            let links = nav.corner_meta.iter().filter(|(flags, jump)| *flags & 0x04 != 0 || (*jump != 0 && *jump != u8::MAX)).count();
            let jumps: Vec<String> = nav.corner_meta.iter().rev().take(8).map(|(f, j)| format!("{f}:{j}")).collect();
            log::info!("BOT_PATH epoch={} t={:.2} slot={} ok={} status={status:#x} partial={} points={} links={links} corners={} end_gap={:.0} sx={:.1} sy={:.1} sz={:.1} gx={:.1} gy={:.1} gz={:.1} target={} suppressed={}",
                super::telemetry::epoch(), time(helper), local_data.edict, result.is_ok() as u8, partial as u8,
                nav.path_points.len(), jumps.join(","), if end_gap.is_finite() { end_gap } else { -1. },
                origin.x, origin.y, origin.z, target_pos.x, target_pos.y, target_pos.z,
                local_data.route_target.unwrap_or(-1), local_data.path_log.take_suppressed());
        }
        if let Err(err) = result {
            local_data.metrics.path_failures = local_data.metrics.path_failures.saturating_add(1);
            log::warn!("navigation pathing failed stuck somewhere probably! {err}");
            face_toward(cmd, origin, target_pos, helper);
            try_avoid_obstacle(cmd, local_data, helper);

            local_data.last_bad_path = time(helper);

            return false;
        }
    }

    if nav
        .end_point
        .map(|point| distance(point, target_pos) > BOT_PATH_RECAL_RANGE)
        .unwrap_or(true)
        || (nav.path_points.is_empty() && !pending_waypoint)
    {
        try_avoid_obstacle(cmd, local_data, helper);
        face_toward(cmd, origin, target_pos, helper);

        return true;
    }

    let corner_height_guard = super::switch_on(&super::CORNER_HEIGHT_GUARD_CONVAR);
    if !corner_height_guard && let Some(since) = local_data.corner_guard_since.take() {
        log::info!("BOT_CORNER_GUARD epoch={} t={:.2} slot={} event=end reason=disabled held_s={:.2}",
            super::telemetry::epoch(),time(helper),local_data.edict,(time(helper)-since).max(0.));
    }
    let human_hull = nav.hull == crate::navmesh::Hull::Human;
    while within_route_corner_range(local_data.next_target_pos, origin, corner_height_guard, human_hull, local_data.current_corner) {
        let Some((next, meta)) = nav.next_corner() else { break; };
        if let Some(since) = local_data.corner_guard_since.take() {
            log::info!("BOT_CORNER_GUARD epoch={} t={:.2} slot={} event=end reason=advance held_s={:.2}",
                super::telemetry::epoch(),time(helper),local_data.edict,(time(helper)-since).max(0.));
        }
        local_data.last_time_node_reached = helper.globals.curTime;
        local_data.next_target_pos = next;
        local_data.current_corner = meta;
        if super::switch_on(&super::NAV_DIAGNOSTICS_CONVAR) {
            log::info!("BOT_CORNER epoch={} t={:.2} slot={} flags={} jump={} class={} remaining={} x={:.1} y={:.1} z={:.1} dz={:.1} dist={:.0}",
                super::telemetry::epoch(), time(helper), local_data.edict,
                meta.map_or(-1, |m| m.0 as i32), meta.map_or(-1, |m| m.1 as i32),
                super::nav_diagnostics::corner_class(meta), nav.path_points.len(),
                next.x, next.y, next.z, next.z - origin.z, distance(next, origin));
        }
    }

    if corner_height_guard && super::switch_on(&super::NAV_DIAGNOSTICS_CONVAR) {
        let horizontal = distance(local_data.next_target_pos, origin);
        let dz = local_data.next_target_pos.z - origin.z;
        if super::route_guard::hold_upward_corner(horizontal,dz,BOT_PATH_NODE_RANGE,human_hull,local_data.current_corner) {
            if local_data.corner_guard_since.is_none() {
                local_data.corner_guard_since = Some(time(helper));
                log::info!("BOT_CORNER_GUARD epoch={} t={:.2} slot={} event=begin dz={:.1}",
                    super::telemetry::epoch(),time(helper),local_data.edict,dz);
            }
            if local_data.corner_guard_log.allow(time(helper), 1.0) {
            log::info!("BOT_CORNER_HOLD epoch={} t={:.2} slot={} flags={} jump={} horizontal={:.0} dz={:.1} waypoint=({:.1},{:.1},{:.1}) origin=({:.1},{:.1},{:.1})",
                super::telemetry::epoch(), time(helper), local_data.edict,
                local_data.current_corner.map_or(-1, |m| m.0 as i32),
                local_data.current_corner.map_or(-1, |m| m.1 as i32),
                horizontal, dz,
                local_data.next_target_pos.x, local_data.next_target_pos.y, local_data.next_target_pos.z,
                origin.x, origin.y, origin.z);
            }
        }
    }

    // Flat routes do not need a constant jump attempt. Finish a short press,
    // then release it before trying again at a step or during recovery.
    let dz = local_data.next_target_pos.z - origin.z;
    let step = if super::switch_on(&super::JUMP_TIMING_CONVAR) {
        super::route_guard::step_jump_wanted(dz, distance(local_data.next_target_pos, origin))
    } else { dz > 18. };
    if super::jump_pulse::jump_pulse(time(helper), &mut local_data.jump_delay,
        &mut local_data.jump_hold, step) {
        cmd.buttons |= Action::Jump as u32;
        cmd.move_.z = 1.0; // hmmm
    }

    face_toward(cmd, origin, local_data.next_target_pos, helper);
    cmd.move_.x = 1.0;
    cmd.buttons |= Action::Forward as u32 | Action::Speed as u32;

    if is_timedout(local_data.last_time_node_reached, helper, 5.) {
        note_failed_link(local_data, origin, helper, "waypoint_timeout");
        // Repeating avoidance against the same stale route never escapes it.
        if let Some(nav) = local_data.nav_query.as_mut() {
            nav.path_points.clear();
            nav.end_point = None;
        }
        local_data.recovery_until = time(helper) + 1.2;
        local_data.stall_event = Some("waypoint_timeout");
        note_stalled_pursuit(local_data, helper, "waypoint_timeout");
        note_recovery(local_data, origin, helper, "waypoint_timeout");
        try_avoid_obstacle(cmd, local_data, helper);
    }

    true
}

/// Suppress only *unseen pursuit* after repeated actual watchdog recoveries.
/// No global route blacklist or navmesh mutation; other bots are unaffected.
fn note_stalled_pursuit(local_data: &mut BotData, helper: &CUserCmdHelper, reason: &str) {
    if !super::switch_on(&super::STALL_TARGET_RECOVERY_CONVAR) { return; }
    let Some(id) = local_data.route_target else { return; };
    if local_data.stall_targets.record(time(helper), id) {
        log::info!("BOT_ROUTE_COOLDOWN epoch={} t={:.2} slot={} target={} reason={} hold=8",
            super::telemetry::epoch(), time(helper), local_data.edict, id, reason);
    }
}

fn note_failed_link(local: &mut BotData, origin: Vector3, helper: &CUserCmdHelper, reason: &str) {
    if !super::switch_on(&super::LINK_DETOUR_CONVAR) && !eden_repair_active(helper) {return;}
    let mask=local.nav_query.as_ref().filter(|n|n.hull==crate::navmesh::Hull::Human)
        .map_or(0,|n|n.segment_traversals);
    if local.link_detour.fail(time(helper),[origin.x,origin.y],mask)
        && super::switch_on(&super::NAV_DIAGNOSTICS_CONVAR) {
        log::info!("BOT_LINK_DETOUR epoch={} t={:.2} slot={} reason={} mask={} duration_s=8 x={:.1} y={:.1} z={:.1}",
            super::telemetry::epoch(),time(helper),local.edict,reason,super::route_guard::LinkDetour::MASK,origin.x,origin.y,origin.z);
    }
}

fn eden_repair_active(helper: &CUserCmdHelper) -> bool {
    if !super::switch_on(&super::EDEN_REPAIR_CONVAR) {return false;}
    let map=unsafe {helper.engine_funcs.server.as_ref()}
        .and_then(|server|crate::utils::get_c_char_array(&server.m_szMapName)).unwrap_or("unknown");
    super::route_guard::eden_repair_enabled(true,map)
}

fn within_route_corner_range(target: Vector3, origin: Vector3, height_guard: bool, human_hull: bool, metadata: Option<(u8,u8)>) -> bool {
    let horizontal = distance(target, origin);
    horizontal <= BOT_PATH_NODE_RANGE && (!height_guard || !super::route_guard::hold_upward_corner(
        horizontal,target.z-origin.z,BOT_PATH_NODE_RANGE,human_hull,metadata))
}

pub fn is_timedout(last_time: f32, helper: &CUserCmdHelper<'_>, time_elasped: f32) -> bool {
    last_time + time_elasped <= time(helper)
}

fn face_toward(cmd: &mut CUserCmd, origin: Vector3, target: Vector3, helper: &CUserCmdHelper) {
    // A duplicate start point has no direction; atan2(0, 0) would snap east.
    if distance(origin, target) > 1. {
        cmd.world_view_angles.y = super::behavior_tuning::turn_yaw(
            helper.angles.y, look_at(origin, target).y,
            540. * helper.globals.frameTime.clamp(0., 0.05));
    }
}

// same here
#[allow(clippy::mut_from_ref)]
pub unsafe fn find_player_in_view<'a>(
    pos: Vector3,
    view: Option<Vector3>,
    team: i32,
    helper: &'a CUserCmdHelper,
    player_index: Option<u32>,
    targets_locks: Option<&[(f32, u32)]>,
) -> Option<(&'a mut CPlayer, bool)> {
    const BOT_VIEW: f32 = 270_f32;
    let mut v = Vector3::ZERO;

    if let Some(target) = unsafe {
        let mut possible_targets = enemy_player_iterator(team, helper)
            .chain(enemy_titan_iterator(helper, team))
            .map(|player| (*player.get_origin(&mut v), player))
            .filter(|(origin, _)| {
                view.map(|view| dot(normalize(*origin - pos), view) > BOT_VIEW.to_radians().cos())
                    .unwrap_or(true)
            })
            .map(|(target, player)| (target, player, distance(target, pos)))
            .filter(|(_, _, dis)| *dis <= BOT_VISON_RANGE)
            .collect::<Vec<(Vector3, &mut CPlayer, f32)>>();
        possible_targets.sort_by(|(_, _, dis1), (_, _, dis2)| dis1.total_cmp(dis2));

        possible_targets
            .into_iter()
            .filter(|(_, target, _)| {
                (helper.sv_funcs.is_titan)(nudge_type::<&CBaseEntity>(target))
                    || targets_locks
                        .and_then(|l| l.get(get_player_index(target)))
                        .copied()
                        .map(|(last_shot, by)| {
                            is_timedout(last_shot, helper, 0.5) || Some(by) == player_index
                        })
                        .unwrap_or(true)
            })
            .find_map(|(target, player, _)| {
                Some(view_rate(helper, pos, target, player, false)).and_then(|(fraction, ent)| {
                    (fraction == 1.0 || std::ptr::addr_eq(ent, player))
                        .then(|| view_rate(helper, pos, target, player, true))
                        .and_then(|(fraction, ent)| {
                            (fraction == 1.0 || std::ptr::addr_eq(ent, player)).then_some(player)
                        })
                })
            })
    } {
        return Some((target, true));
    }

    None
}

pub fn farthest_player<'a>(
    pos: Vector3,
    team: i32,
    helper: &'a CUserCmdHelper,
) -> Option<&'a mut CPlayer> {
    distance_iterator(&pos, enemy_player_iterator(team, helper))
        .reduce(|closer, other| if closer.0 < other.0 { other } else { closer })
        .map(|(_, player)| player)
}

pub fn closest_player<'a>(
    pos: Vector3,
    team: i32,
    helper: &'a CUserCmdHelper,
) -> Option<&'a mut CPlayer> {
    distance_iterator(&pos, enemy_player_iterator(team, helper))
        .reduce(|closer, other| if closer.0 < other.0 { other } else { closer })
        .map(|(_, player)| player)
}

pub fn enemy_player_iterator<'b, 'a: 'b>(
    team: i32,
    helper: &'a CUserCmdHelper,
) -> impl Iterator<Item = &'a mut CPlayer> + 'b {
    (0..32)
        .filter_map(|i| unsafe { (helper.sv_funcs.get_player_by_index)(i + 1).as_mut() })
        .filter(move |player| player.m_iTeamNum != team && player.m_iTeamNum != 0)
        .filter(|player| unsafe {
            (helper.sv_funcs.is_alive)(nudge_type::<&CBaseEntity>(player)) != 0
        })
}

pub fn enemy_titan_iterator<'b, 'a: 'b>(
    helper: &'b CUserCmdHelper<'_>,
    team: i32,
) -> impl Iterator<Item = &'a mut CPlayer> + 'b {
    (0..32)
        .filter_map(|i| unsafe { (helper.sv_funcs.get_player_by_index)(i + 1).as_mut() })
        .filter(move |player| player.m_iTeamNum != team && player.m_iTeamNum != 0)
        .filter_map(|player| {
            unsafe {
                (helper.sv_funcs.get_pet_titan)(player)
                    .cast::<CPlayer>()
                    .cast_mut()
                    .as_mut()
                    .and_then(|titan| {
                        (helper.sv_funcs.is_alive)(nudge_type::<&CBaseEntity>(titan))
                            .eq(&1)
                            .then_some(titan)
                    })
            } // probably safe since the functions should be the same in the vtale, right?
        })
}

pub fn player_iterator<'b, 'a: 'b>(
    predicate: &'b impl Fn(&CPlayer) -> bool,
    helper: &'a CUserCmdHelper,
) -> impl Iterator<Item = &'a mut CPlayer> + 'b {
    (0..32)
        .filter_map(|i| unsafe { (helper.sv_funcs.get_player_by_index)(i + 1).as_mut() })
        .filter(|player| predicate(player))
        .filter(|player| unsafe {
            (helper.sv_funcs.is_alive)(nudge_type::<&CBaseEntity>(player)) != 0
        })
}

pub fn titan_iterator<'b, 'a: 'b>(
    predicate: &'b impl Fn(&CPlayer) -> bool,
    helper: &'a CUserCmdHelper,
) -> impl Iterator<Item = &'a mut CPlayer> + 'b {
    player_iterator(predicate, helper).filter_map(|player| {
        unsafe {
            (helper.sv_funcs.get_pet_titan)(player)
                .cast::<CPlayer>()
                .cast_mut()
                .as_mut()
        } // probably safe since the functions should be the same in the vtale, right?
    })
}

pub fn distance_iterator<'b, 'a: 'b>(
    pos: &'b Vector3,
    players: impl Iterator<Item = &'a mut CPlayer> + 'b,
) -> impl Iterator<Item = (i64, &'a mut CPlayer)> + 'b {
    static mut V: Vector3 = Vector3::ZERO;
    players
        .map(|player| {
            (
                unsafe { *player.get_origin(std::ptr::addr_of_mut!(V)) },
                player,
            )
        })
        .map(|(target, player)| (distance(*pos, target) as i64, player))
}

#[allow(unused)]
pub fn view_rate(
    helper: &CUserCmdHelper,
    v1: Vector3,
    v2: Vector3,
    player: *mut CPlayer,
    corretness: bool,
) -> (f32, *const CBaseEntity) {
    const TRACE_MASK_SHOT: i32 = 1178615859;
    const TRACE_MASK_SOLID_BRUSHONLY: i32 = 16907;
    const TRACE_COLLISION_GROUP_BLOCK_WEAPONS: i32 = 0x12; // 18

    // should maybe revist the consturction of ray
    let mut result: MaybeUninit<CGameTrace> = MaybeUninit::zeroed();
    let mut ray = Ray {
        start: VectorAligned { vec: v1, w: 0. },
        delta: VectorAligned {
            vec: v2 - v1 + GROUND_OFFSET,
            w: 0.,
        },
        offset: VectorAligned {
            vec: Vector3::new(0., 0., 0.),
            w: 0.,
        },
        unk3: 0.,
        unk4: 0,
        unk5: 0.,
        unk6: 1103806595072,
        unk7: 0.,
        is_ray: true,
        is_swept: false,
        is_smth: false,
        flags: 0,
        unk8: 0,
    };

    if corretness {
        let filter: *const CTraceFilterSimple = &CTraceFilterSimple {
            vtable: helper.sv_funcs.simple_filter_vtable,
            unk: 0,
            pass_ent: player.cast(),
            should_hit_func: std::ptr::null(),
            collision_group: TRACE_COLLISION_GROUP_BLOCK_WEAPONS,
        };

        // could use this to get 100% result and trace ray for a aproximation of failure
        unsafe {
            (helper.engine_funcs.trace_ray_filter)(
                (*helper.sv_funcs.ctraceengine) as *const libc::c_void,
                &mut ray,
                TRACE_MASK_SHOT as u32,
                filter.cast(),
                result.as_mut_ptr(),
            )
        };
    } else {
        unsafe {
            (helper.engine_funcs.trace_ray)(
                (*helper.sv_funcs.ctraceengine) as *const libc::c_void,
                &mut ray,
                TRACE_MASK_SHOT as u32,
                result.as_mut_ptr(),
            )
        };
    }
    let result = unsafe { result.assume_init() };

    if !result.start_solid && result.fraction_left_solid == 0.0 {
        (result.fraction, result.hit_ent)
    } else {
        (0.0, result.hit_ent)
    }
}

pub fn try_avoid_obstacle(cmd: &mut CUserCmd, local_data: &mut BotData, helper: &CUserCmdHelper) {
    local_data.metrics.state = "recover";
    if escape_recovery_enabled(local_data)
        && let Some(side) = local_data.escape_recovery.backstep_side(time(helper), local_data.edict) {
        cmd.move_ = Vector3::new(-0.8, side, 0.);
        cmd.buttons &= !(Action::Forward as u32 | Action::Jump as u32);
        cmd.buttons |= Action::Back as u32 | Action::Speed as u32;
        return;
    }
    cmd.move_ = Vector3::new(
        1.,
        if helper.globals.frameCount / 100 % 2 == 0 {
            -1.
        } else {
            1.
        },
        0.,
    );
    cmd.buttons |= Action::Forward as u32
        | Action::Speed as u32;
    let retry_jump = is_timedout(local_data.jump_delay, helper, 1.2);
    if super::jump_pulse::jump_pulse(time(helper), &mut local_data.jump_delay,
        &mut local_data.jump_hold, retry_jump) {
        cmd.buttons |= Action::Jump as u32;
    }
}

fn note_recovery(local: &mut BotData, origin: Vector3, helper: &CUserCmdHelper, reason: &str) {
    if escape_recovery_enabled(local) {
        local.escape_recovery.stalled(time(helper), [origin.x, origin.y]);
        if super::switch_on(&super::STALL_RETARGET_CONVAR) && local.escape_recovery.repeated(time(helper))
            && let Some(target) = local.route_target {
            local.unreachable.avoid(time(helper), target);
            if super::TELEMETRY_CONVAR.get().is_some_and(|c| c.get_value_f32() > 0.) {
                log::info!("BOT_RETARGET epoch={} t={:.2} slot={} target={} reason=repeated_local_stall hold=6 x={:.1} y={:.1} z={:.1}",
                    super::telemetry::epoch(), time(helper), local.edict, target, origin.x, origin.y, origin.z);
            }
        }
        if let Some(side) = local.escape_recovery.backstep_side(time(helper), local.edict)
            && super::TELEMETRY_CONVAR.get().is_some_and(|c| c.get_value_f32() > 0.) {
            log::info!("BOT_ESCAPE epoch={} t={:.2} slot={} side={side} x={:.1} y={:.1} z={:.1}",
                super::telemetry::epoch(), time(helper), local.edict, origin.x, origin.y, origin.z);
        }
    }
    local.metrics.recoveries = local.metrics.recoveries.saturating_add(1);
    if super::TELEMETRY_CONVAR.get().is_some_and(|c| c.get_value_f32() > 0.) {
        log::info!("BOT_RECOVERY epoch={} t={:.2} slot={} reason={reason} x={:.1} y={:.1} z={:.1}",
            super::telemetry::epoch(), time(helper), local.edict, origin.x, origin.y, origin.z);
    }
}

pub fn time(helper: &CUserCmdHelper<'_>) -> f32 {
    helper.globals.curTime
}

fn escape_recovery_enabled(local: &BotData) -> bool {
    super::ESCAPE_RECOVERY_CONVAR.get().is_some_and(|c| c.get_value_bool())
        && local.sim_type.unwrap_or_else(|| super::SIMULATE_TYPE_CONVAR.wait().get_value_i32()) == 6
        && local.nav_query.as_ref().is_some_and(|q| q.hull == crate::navmesh::Hull::Human)
}

pub fn distance(pos: Vector3, target: Vector3) -> f32 {
    ((pos.x - target.x).powi(2) + (pos.y - target.y).powi(2)).sqrt()
}

pub fn distance3(pos: Vector3, target: Vector3) -> f32 {
    ((pos.x - target.x).powi(2) + (pos.y - target.y).powi(2) + (pos.z - target.z).powi(2)).sqrt()
}

pub fn dot(vec: Vector3, other_vec: Vector3) -> f32 {
    (vec.x * other_vec.x) + (vec.y * other_vec.y) + (vec.z * other_vec.z)
}

pub fn normalize(vec: Vector3) -> Vector3 {
    let length_recip = dot(vec, vec).sqrt().recip();
    Vector3::new(
        vec.x * length_recip,
        vec.y * length_recip,
        vec.z * length_recip,
    )
}

pub fn get_velocity_length(helper: &CUserCmdHelper, player: &mut CPlayer, v: &mut Vector3) -> f32 {
    let velocity = get_velocity_vector(helper, player, v);
    (velocity.x.powi(2) + velocity.y.powi(2)).sqrt()
}

pub fn get_velocity_vector(
    helper: &CUserCmdHelper,
    player: &mut CPlayer,
    v: &mut Vector3,
) -> Vector3 {
    unsafe { *(helper.sv_funcs.get_smoothed_velocity)(player, v) }
}
