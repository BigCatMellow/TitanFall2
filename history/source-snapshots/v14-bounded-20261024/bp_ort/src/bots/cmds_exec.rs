use rrplug::{
    bindings::class_types::client::SignonState,
    high::{UnsafeHandle, vector::Vector3},
    prelude::EngineToken,
};
use std::cell::UnsafeCell;

use super::{BOT_DATA_MAP, SHARED_BOT_DATA, SIMULATE_TYPE_CONVAR, cmds_helper::CUserCmdHelper};
use crate::{
    bindings::{Action, CUserCmd, ENGINE_FUNCTIONS, SERVER_FUNCTIONS},
    utils::iterate_c_array_sized,
};

static LAST_CMD: UnsafeHandle<UnsafeCell<Option<CUserCmd>>> =
    unsafe { UnsafeHandle::new(UnsafeCell::new(None)) };

pub fn replace_cmd() -> Option<&'static CUserCmd> {
    unsafe { LAST_CMD.get().get().as_ref()?.as_ref() }
}

pub fn run_bots_cmds(paused: bool) {
    // Physics callbacks can run during map teardown/loading. Per-bot queries
    // must not touch the old navmesh after its server VM has been destroyed.
    if !crate::PLUGIN.wait().bots.server_vm_active.load(std::sync::atomic::Ordering::Acquire) {
        return;
    }
    let sim_type = SIMULATE_TYPE_CONVAR.wait().get_value_i32();
    let server_functions = SERVER_FUNCTIONS.wait();
    let engine_functions = ENGINE_FUNCTIONS.wait();
    let player_by_index = server_functions.get_player_by_index;
    let globals =
        unsafe { engine_functions.globals.as_mut() }.expect("globals were null for some reason");

    let token = unsafe { EngineToken::new_unchecked() };
    let mut bot_local_data = BOT_DATA_MAP.get(token).borrow_mut();
    let mut bot_shared_data = SHARED_BOT_DATA.get(token).borrow_mut();
    let interval = super::TELEMETRY_CONVAR.get().map_or(0., |c| c.get_value_f32());
    let emit_trace = interval.is_finite() && interval > 0. && globals.curTime >= bot_shared_data.telemetry_next_at;
    let epoch = super::telemetry::epoch();
    let map = unsafe { engine_functions.server.as_ref() }
        .and_then(|server| crate::utils::get_c_char_array(&server.m_szMapName)).unwrap_or("unknown");
    if emit_trace {
        bot_shared_data.telemetry_next_at = globals.curTime + interval.clamp(0.5, 10.);
        let coordinated = super::COORDINATION_CONVAR.get().is_some_and(|c| c.get_value_bool());
        log::info!("BOT_FRAME epoch={epoch} map={map} t={:.2} tick={} coordination={} route_recovery={}",
            globals.curTime, globals.tickCount, coordinated as u8,
            super::ROUTE_RECOVERY_CONVAR.get().is_some_and(|c| c.get_value_bool()) as u8);
        for (slot, client) in unsafe { iterate_c_array_sized::<_, 32>(engine_functions.client_array.into()) }
            .enumerate().filter(|(_, c)| c.m_nSignonState == SignonState::FULL) {
            if let Some(player) = unsafe { player_by_index(slot as i32 + 1).as_ref() } {
                let pos = player.m_vecAbsOrigin;
                let alive = unsafe { (server_functions.is_alive)(std::ptr::from_ref(player).cast()) } != 0;
                let titan = unsafe { (server_functions.is_titan)(std::ptr::from_ref(player).cast()) };
                log::info!("BOT_PLAYER epoch={epoch} map={map} t={:.2} slot={slot} id={} team={} bot={} alive={} titan={} hp={} x={:.1} y={:.1} z={:.1}",
                    globals.curTime, player.m_RefEHandle, player.m_iTeamNum, client.m_bFakePlayer as u8,
                    alive as u8, titan as u8, player.m_iHealth, pos.x, pos.y, pos.z);
            }
        }
    }

    crate::PLUGIN
        .wait()
        .bots
        .external_simulations
        .simulations
        .read()
        .iter()
        .filter_map(|(_, sim)| sim.pre_simulate)
        .for_each(|pre_simulate| pre_simulate(paused));

    for (player, edict) in unsafe {
        iterate_c_array_sized::<_, 32>(engine_functions.client_array.into())
            .enumerate()
            .filter(|(_, client)| client.m_nSignonState == SignonState::FULL)
            .filter(|(_, client)| client.m_bFakePlayer)
            .filter_map(|(i, client)| {
                let bot_player = player_by_index((i + 1) as i32).as_mut()?;
                let handle = client.m_nHandle as usize - 1; // eh

                // (server_functions.calc_origin)(
                //     nudge_type::<&CBaseEntity>(bot_player),
                //     &std::ptr::from_ref(bot_player),
                //     0,
                //     0,
                // );

                Some((bot_player, handle))
            })
    } {
        let Some(local_data) = bot_local_data.get_mut(edict) else {
            log::warn!("bot {edict} without valid local data entry");
            continue;
        };

        let mut cmd = {
            local_data.edict = edict as u16;

            let helper = CUserCmdHelper::new(
                globals,
                Vector3::ZERO,
                0,
                server_functions,
                engine_functions,
            );

            super::cmds::get_cmd(
                player,
                &helper,
                local_data.sim_type.unwrap_or(sim_type),
                local_data,
                &mut bot_shared_data,
            )
            .unwrap_or_else(|| CUserCmd::new_empty(&helper))
        };

        cmd.frame_time = globals.frameTime;
        local_data.metrics.command(cmd.world_view_angles.y, cmd.buttons & Action::Jump as u32 != 0);
        if emit_trace {
            let metrics = &local_data.metrics;
            let velocity = player.m_vecAbsVelocity;
            let speed = (velocity.x * velocity.x + velocity.y * velocity.y).sqrt();
            let support = metrics.target.map_or(0, |target| bot_shared_data.coordination.supporters(
                edict, player.m_iTeamNum, target, globals.curTime));
            log::info!("BOT_TRACE epoch={epoch} map={map} t={:.2} slot={edict} target={} visible={} state={} tx={:.1} ty={:.1} tz={:.1} speed={speed:.1} yaw={:.1} switches={} recoveries={} path_failures={} path_requests={} jumps={} commands={} yaw_travel={:.1} supporters={support} nodes={} neighbors={} spacing={} failed_goal_skips={} retreats={}",
                globals.curTime, metrics.target.unwrap_or(-1), metrics.visible as u8, metrics.state,
                metrics.target_pos[0], metrics.target_pos[1], metrics.target_pos[2], cmd.world_view_angles.y,
                metrics.switches, metrics.recoveries, metrics.path_failures, metrics.path_requests,
                metrics.jump_commands, metrics.commands, metrics.yaw_travel,
                local_data.nav_query.as_ref().map_or(0, |n| n.path_points.len()), metrics.neighbors, metrics.spacing_commands,
                metrics.failed_goal_skips, metrics.retreats);
        }
        if super::MOTION_DEBUG_CONVAR.get().is_some_and(|c| c.get_value_bool()) {
            let origin = player.m_vecAbsOrigin;
            if let Some((last, previous)) = local_data.motion_sample {
                if globals.curTime - last >= 10. {
                    let delta = origin - previous;
                    let travel = (delta.x * delta.x + delta.y * delta.y).sqrt();
                    log::info!("BOT_MOTION slot={edict} mode={} hp={} pos={origin:?} horizontal_delta={travel:.1} velocity={:?} move={:?} buttons={:#x} next={:?} route_nodes={} hold={} aim_error_scale={:.2}",
                        local_data.sim_type.unwrap_or(sim_type), player.m_iHealth,
                        player.m_vecAbsVelocity, cmd.move_, cmd.buttons, local_data.next_target_pos,
                        local_data.nav_query.as_ref().map_or(0, |n| n.path_points.len()), local_data.jump_hold,
                        super::behavior_tuning::aim_error_scale(super::AIM_ERROR_SCALE_CONVAR.get().map_or(1., |c| c.get_value_f32())));
                    local_data.motion_sample = Some((globals.curTime, origin));
                }
            } else {
                local_data.motion_sample = Some((globals.curTime, origin));
            }
        }
        player.pl.fixangle = 0;
        unsafe {
            (server_functions.proccess_user_cmds)(player, &cmd, 1, 1, 0, false);
        }
    }
}
