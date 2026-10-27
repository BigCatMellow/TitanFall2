#![deny(clippy::unwrap_used, clippy::expect_used)]
use high::squirrel::call_sq_function;
use mid::squirrel::SQVM_SERVER;
use rand::{Rng, thread_rng};
use rrplug::{
    bindings::class_types::{cbaseentity::CBaseEntity, cplayer::CPlayer, cweaponx::CWeaponX},
    high::UnsafeHandle,
    prelude::{EngineToken, *},
};
use shared::{
    classes::get_player_titan_class,
    utils::{get_player_index, nudge_type},
};
use std::{cell::UnsafeCell, sync::atomic::Ordering};

use crate::{
    bindings::{Action, CUserCmd},
    bots::{AIM_PENALTY_VALUE, BotData, cmds_helper::CUserCmdHelper, cmds_utils::*},
    utils::{get_ents_by_class_name, get_net_var, get_weaponx_name, lookup_ent},
};

use super::BotShared;

/// this cannot be accessed from multiple places so it's safe
static HEADHUNTER_DATA: EngineGlobal<UnsafeCell<HeadHunterData>> =
    EngineGlobal::new(UnsafeCell::new(HeadHunterData {
        last_checked: -1,
        batteries: Vec::new(),
        hardpoints: Vec::new(),
    }));
static CTF_DATA: EngineGlobal<UnsafeCell<CtfData>> = EngineGlobal::new(UnsafeCell::new(CtfData {
    last_checked: -1,
    flags: Vec::new(),
    bases: Vec::new(),
}));

struct HeadHunterData {
    last_checked: i32,
    batteries: Vec<Vector3>,
    hardpoints: Vec<Vector3>,
}

struct CtfData {
    last_checked: i32,
    flags: Vec<(Vector3, i32, u32)>,
    bases: Vec<(Vector3, i32)>,
}

// TODO INFO bots may be crashing "in titans" when in fact they crash when checking a player when they are embarking
pub(crate) fn basic_combat(
    player: &mut CPlayer,
    helper: &CUserCmdHelper,
    sim_type: i32,
    local_data: &mut BotData,
    shared_data: &mut BotShared,
) -> CUserCmd {
    let mut v = Vector3::ZERO;
    let v = &mut v;
    let origin = unsafe { *player.get_origin(v) };
    let team = player.m_iTeamNum;
    let is_titan = unsafe { (helper.sv_funcs.is_titan)(nudge_type::<&CBaseEntity>(player)) };
    let combat_enabled = !is_titan && sim_type == 6
        && crate::bots::COMBAT_DECISIONS_CONVAR.get().is_some_and(|c| c.get_value_bool());
    let mut combat_target_is_titan = false;
    let action_policy = !is_titan && sim_type == 6
        && crate::bots::ACTION_POLICY_CONVAR.get().is_some_and(|c| c.get_value_bool());
    if !combat_enabled { local_data.combat.tactic = "legacy"; }

    let target = if !is_titan && sim_type == 6
        && crate::bots::COORDINATION_CONVAR.get().is_some_and(|c| c.get_value_bool()) {
        unsafe { find_team_target(origin, team, player, helper, local_data, &shared_data.coordination) }
    } else { unsafe {
        find_player_in_view(
            origin,
            Some(*(helper.sv_funcs.view_angles)(player, v)),
            team,
            helper,
            None,
            None,
            // disabled for now since it doesn't actually help instead it makes them worse
            // Some(player.player_index.copy_inner()),
            // Some(shared.reserved_targets.as_ref()),
        )
        .map(|(player, should_shoot)| ((*player.get_origin(v), player), should_shoot))
        .or_else(|| {
            distance_iterator(
                &origin,
                enemy_player_iterator(team, helper).chain(enemy_titan_iterator(helper, team)),
            )
            .reduce(|closer, other| if closer.0 < other.0 { other } else { closer })
            .map(|(_, player)| player)
            .map(|player| ((*player.get_origin(v), player), false))
        })
    } };

    let target_id = target.as_ref().map(|((_, target), _)| target.m_RefEHandle);
    let target_index = target.as_ref().map(|((_, target), _)| get_player_index(target));
    // Set again by whichever branch actually requests a pursuit route.
    local_data.route_target = None;
    let cover_active = !is_titan && sim_type == 6
        && crate::bots::switch_on(&crate::bots::HEIGHT_RESPONSE_CONVAR)
        && local_data.height.active(time(helper)).is_some();
    if !local_data.view_checked && !is_titan && crate::bots::switch_on(&crate::bots::NAV_DIAGNOSTICS_CONVAR) {
        local_data.view_checked = true;
        log_view_and_hulls(player, helper, local_data);
    }
    if local_data.metrics.target.is_some() && target_id.is_some()
        && local_data.metrics.target != target_id {
        local_data.metrics.switches = local_data.metrics.switches.saturating_add(1);
        if crate::bots::TELEMETRY_CONVAR.get().is_some_and(|c| c.get_value_f32() > 0.) {
            log::info!("BOT_DECISION epoch={} t={:.2} slot={} old={} target={} reason={} actor={}",
                crate::bots::telemetry::epoch(), time(helper), local_data.edict,
                local_data.metrics.target.unwrap_or(-1), target_id.unwrap_or(-1),
                if target.as_ref().is_some_and(|(_, visible)| *visible) { "engage" } else { "pursue" },
                if is_titan { "titan" } else { "pilot" });
        }
    }
    local_data.metrics.target = target_id;
    local_data.metrics.visible = target.as_ref().is_some_and(|(_, visible)| *visible);
    local_data.metrics.state = if local_data.metrics.visible { "engage" }
        else if target_id.is_some() { "pursue" } else { "idle" };
    if let Some(((pos, _), _)) = target.as_ref() {
        local_data.metrics.target_pos = [pos.x, pos.y, pos.z];
    }
    if let Some(id) = target_id {
        shared_data.coordination.commit(local_data.edict as usize, team, id, time(helper));
    } else {
        shared_data.coordination.clear(local_data.edict as usize);
    }

    let mut cmd = CUserCmd::new_basic_move(Vector3::ZERO, 0, helper);

    match (sim_type, &target) {
        (6, target) if target.is_none() || matches!(target, Some((_, false))) => {
            if let Some(pet_titan) = unsafe { (helper.sv_funcs.get_pet_titan)(player).as_ref() } {
                local_data.metrics.state = "embark";
                local_data.route_target = None;
                path_to_target(
                    &mut cmd,
                    local_data,
                    player.m_vecAbsOrigin,
                    unsafe { *pet_titan.get_origin(v) },
                    local_data.should_recalculate_path,
                    helper,
                );
            } else if let Some(((target_pos, target), _)) = target
                && !cover_active
                && { local_data.route_target = Some(target.m_RefEHandle); true }
                && path_to_target(
                    &mut cmd,
                    local_data,
                    player.m_vecAbsOrigin,
                    *target_pos,
                    local_data.last_target_index != get_player_index(target)
                        || local_data.should_recalculate_path,
                    helper,
                )
            {
                local_data.last_target_index = get_player_index(target)
            }

            local_data.should_recalculate_path = false;
        }
        (7, vision) if vision.is_none() || matches!(vision, Some((_, false))) => {
            // this may be a big issue here
            // this sometimes does need to recalculate the path
            _ = path_to_target(
                &mut cmd,
                local_data,
                player.m_vecAbsOrigin,
                local_data.target_pos,
                local_data.should_recalculate_path,
                helper,
            );

            local_data.should_recalculate_path = false;
        }
        (8, target) if target.is_none() || matches!(target, Some((_, false))) => {
            let (new_target_pos, should_recaculate) =
            // check if team members are dead
                if get_net_var(player, c"batteryCount", 191, helper.sv_funcs).unwrap_or(0) > 0{
                    local_data.approach_range = Some(70.);
                    (find_closest_hardpoint(origin, helper), None)
                } else if let Some(battery) = find_closest_battery(origin, helper) {
                    local_data.approach_range = Some(-20.);
                    (battery, None)
                } else if let Some(((target_pos, target), _)) = target {
                    let result = (
                        *target_pos,
                        Some(
                            local_data.last_target_index
                                != get_player_index(target) ,
                        ),
                    );
                    local_data.last_target_index = get_player_index(target);

                    result
                } else {
                    local_data.approach_range = Some(200.);
                    (find_closest_hardpoint(origin, helper), None)
                };

            _ = path_to_target(
                &mut cmd,
                local_data,
                player.m_vecAbsOrigin,
                new_target_pos,
                should_recaculate.unwrap_or_else(|| local_data.target_pos != new_target_pos)
                    || local_data.should_recalculate_path,
                helper,
            );

            // not the actual use but it's okay
            local_data.target_pos = new_target_pos;
            local_data.should_recalculate_path = false;
            local_data.approach_range = None;
        }
        (9, target) if target.is_none() || matches!(target, Some((_, false))) => {
            let (team, player_index) = (player.m_iTeamNum, get_player_index(player) as u32);
            let our_flag = find_flag_for(team, true, player_index, helper);
            let their_flag = find_flag_for(team, false, player_index, helper);
            let our_base = find_base_for(team, true, helper);
            let _their_base = find_base_for(team, false, helper);

            let is_team = move |player: &CPlayer| -> bool { player.m_iTeamNum == team };
            // mm allocation every frame
            let mut friendly_players = player_iterator(&is_team, helper)
                .map(|friendly| {
                    (
                        unsafe { distance(*friendly.get_origin(v), their_flag.0) },
                        std::ptr::eq(friendly, player),
                    )
                })
                .collect::<Vec<_>>();
            friendly_players.sort_by(|(dis, _), (other_dis, _)| dis.total_cmp(other_dis));

            let (new_target_pos, should_recaculate) = if let Some(pet_titan) =
                unsafe { (helper.sv_funcs.get_pet_titan)(player).as_ref() }
            {
                (unsafe { *pet_titan.get_origin(v) }, Some(false))
            } else if their_flag.1 {
                local_data.approach_range = Some(-20.);
                (our_base, None)
            } else if friendly_players
                .iter()
                .position(|(_, is_self)| *is_self)
                .unwrap_or(usize::MAX)
                < friendly_players.len() / 2
            {
                local_data.approach_range = Some(-20.);
                (their_flag.0, None)
            } else if distance(our_flag.0, our_base) > 30. {
                local_data.approach_range = Some(0.);
                (our_flag.0, None)
            } else if (time(helper) as u64).div_euclid(30).is_multiple_of(2) {
                (their_flag.0, None)
            } else {
                (our_flag.0, None)
            };

            _ = path_to_target(
                &mut cmd,
                local_data,
                player.m_vecAbsOrigin,
                new_target_pos,
                should_recaculate.unwrap_or_else(|| local_data.target_pos != new_target_pos)
                    || local_data.should_recalculate_path,
                helper,
            );

            // not the actual use but it's okay
            local_data.target_pos = new_target_pos;
            local_data.should_recalculate_path = false;
            local_data.approach_range = None;
        }
        (10, target) if target.is_none() || matches!(target, Some((_, false))) => {
            super::hardpoint::basic_cap_holding(
                player, helper, local_data, origin, &mut cmd, target,
            );
        }
        (_, Some((_, _))) => {
            cmd.move_ = Vector3::new(1., 0., 0.);
            cmd.buttons |= Action::Forward as u32 | Action::Walk as u32;

            // Combat movement keeps following the route while engaged, so the
            // route is not invalidated every visible frame.
            if !(combat_enabled && crate::bots::switch_on(&crate::bots::COMBAT_MOVEMENT_CONVAR)) {
                local_data.should_recalculate_path = true;
            }
        }
        _ => {}
    }

    cmd.buttons |= if matches!(target, Some((_, true))) && !is_titan {
        // pilot abilities TODO: check for cooldown
        match lookup_ent(player.m_inventory.offhandWeapons[1], helper.sv_funcs)
                .and_then(|ent| get_weaponx_name(ent, helper.sv_funcs))
                .unwrap_or_default()
            {
                "mp_weapon_grenade_sonar" => Action::OffHand1 as u32,
                "mp_ability_cloak" => Action::OffHand1 as u32,
                "mp_ability_grapple" => 0,
                "mp_ability_heal" if player.m_iHealth < 50 => Action::OffHand1 as u32,
                "mp_ability_shifter" if player.m_iHealth < 50 => Action::OffHand1 as u32,
                "mp_ability_holopilot" if player.m_iHealth < 50 => Action::OffHand1 as u32,
                _ => 0,
            }
            .saturating_mul((time(helper) as u32 % 25 < 10) as u32)
                // pilot grenades TODO: check for cooldown
                | match lookup_ent(player.m_inventory.offhandWeapons[0], helper.sv_funcs)
                    .and_then(|ent| get_weaponx_name(ent, helper.sv_funcs))
                    .unwrap_or_default()
                {
                    "mp_ability_shifter" if player.m_iHealth < 50 => Action::OffHand0 as u32,
                    "mp_weapon_grenade_sonar" => Action::OffHand0 as u32,
                    "mp_weapon_grenade_gravity" => Action::OffHand0 as u32,
                    "mp_weapon_thermite_grenade" => Action::OffHand0 as u32,
                    "mp_weapon_grenade_emp" => Action::OffHand0 as u32,
                    _ => 0,
                }
                .saturating_mul((time(helper) as u32 % 25 < 3) as u32)
    } else {
        0
    };

    if !is_titan && action_policy && matches!(target, Some((_, true)))
        && crate::bots::switch_on(&crate::bots::DEFENSIVE_TACTICS_CONVAR)
        && lookup_ent(player.m_inventory.offhandWeapons[1], helper.sv_funcs)
            .and_then(|ent| get_weaponx_name(ent, helper.sv_funcs))
            .is_some_and(|name| crate::bots::action_policy::defensive_now(name, player.m_iHealth))
    {
        // Readiness gating below (Pulse) still decides whether it is pressed.
        cmd.buttons |= Action::OffHand1 as u32;
    }

    if let Some(((target, target_player), should_shoot)) = target {
        if let Some(target) = shared_data
            .reserved_targets
            .get_mut(get_player_index(target_player))
        {
            // a last shot target system would be a lot better imo or even preferred target
            *target = (time(helper), get_player_index(player) as u32);
        }

        let active_weapon = lookup_ent(player.m_inventory.activeWeapon, helper.sv_funcs)
            .and_then::<&CWeaponX, _>(|weapon| weapon.dynamic_cast());

        // 0x2c is the offset to weather the weapon can charge or not
        let (should_charge, charge_weapon) = active_weapon
            .map(|weapon| (weapon, weapon.m_lastChargeFrac != 0.))
            .map::<(&CBaseEntity, bool), _>(|x| (x.0, x.1))
            .map(|(weapon, is_charge)| unsafe {
                let charge = (helper.sv_funcs.get_weapon_charge_fraction)(weapon);
                (
                    is_charge
                        && charge < 1.
                        && !(charge == 0. && helper.globals.frameCount / 2 % 4 != 0),
                    is_charge,
                )
            })
            .unwrap_or_default();

        cmd.buttons |= if should_shoot && is_timedout(local_data.last_shot, helper, 0.8) {
            Action::Zoom as u32
                | if (!charge_weapon && helper.globals.frameCount / 2 % 4 != 0) || should_charge {
                    Action::Attack as u32
                } else {
                    Default::default()
                }
        } else if should_shoot {
            0
        } else {
            local_data.last_shot = helper.globals.curTime;
            0
        };

        let target =
            if let Some(titan) = unsafe { (helper.sv_funcs.get_pet_titan)(player).as_ref() } {
                let titan_pos = unsafe { *titan.get_origin(v) };

                let (dis, ent) = view_rate(helper, titan_pos, origin, player, true);
                if dis >= 1.0 || ent == std::ptr::from_ref(titan) {
                    let near = if crate::bots::switch_on(&crate::bots::PROXIMITY_FIX_CONVAR) {
                        crate::bots::perception::within_xy(origin.x - titan_pos.x, origin.y - titan_pos.y, 81000.)
                    } else {
                        (origin.x - titan_pos.x).powi(2) * (origin.y - titan_pos.y).powi(2) < 81000.
                    };
                    if near
                        && (helper.globals.frameCount / 2 % 4 != 0)
                    {
                        cmd.world_view_angles = look_at(origin, titan_pos);
                        cmd.buttons |= Action::Use as u32;
                    }
                    titan_pos
                } else {
                    target
                }
            } else {
                target
            };

        let enemy_is_titan =
            unsafe { (helper.sv_funcs.is_titan)(nudge_type::<&mut CBaseEntity>(target_player)) };
        combat_target_is_titan = enemy_is_titan;

        if should_shoot || sim_type == 5 || sim_type == 4 {
            // for some reason this makes the game freeze later in the frame????
            // if local_data.spread.len() < local_data.spread_offset {
            //     generate_spread(player.m_vecAbsVelocity, &mut local_data.spread);
            //     local_data.spread_offset = 0;
            // }

            let angles = look_at(origin, target);

            let angles = {
                let length = { get_velocity_length(helper, target_player, v) };

                if length > AIM_PENALTY_VALUE.load(Ordering::Relaxed) as f32 && !enemy_is_titan {
                    let mut rng = thread_rng();
                    let scale = crate::bots::behavior_tuning::aim_error_scale(
                        crate::bots::AIM_ERROR_SCALE_CONVAR.get().map_or(1., |c| c.get_value_f32()));
                    let error_amount = (length + 50.).sqrt() / 7f32 * scale;

                    Vector3 {
                        x: angles.x + error_amount * rng.gen_range(-2..=2) as f32,
                        y: angles.y + error_amount * rng.gen_range(-2..=2) as f32,
                        z: 0.,
                    }
                } else if sim_type == 5 || sim_type == 4 {
                    angles
                } else {
                    local_data.spread_offset += 1;

                    angles
                        + local_data
                            .spread
                            .get(local_data.spread_offset)
                            .copied()
                            .unwrap_or(Vector3::ZERO)
                }
            };

            cmd.world_view_angles.x = angles.x;
            cmd.world_view_angles.y = crate::bots::behavior_tuning::turn_yaw(
                cmd.world_view_angles.y, angles.y, 10.);
        } else {
            local_data.spread_offset = local_data.spread.len();
        }

        if (!is_titan && if combat_enabled {
            !enemy_is_titan && crate::bots::combat_decisions::pilot_melee(
                origin.x - target.x, origin.y - target.y, origin.z - target.z)
        } else {
            (origin.x - target.x).powi(2) * (origin.y - target.y).powi(2) < 81000.
                && (origin.z - target.z).abs() < 50.
        })
            || (is_titan
                && if crate::bots::switch_on(&crate::bots::PROXIMITY_FIX_CONVAR) {
                    crate::bots::perception::within_xy(origin.x - target.x, origin.y - target.y, 850000.)
                } else {
                    (origin.x - target.x).powi(2) * (origin.y - target.y).powi(2) < 850000.
                }
                && (origin.z - target.z).abs() < 200.)
        {
            cmd.buttons |= Action::Melee as u32;
        };

        if is_titan && local_data.counter.is_multiple_of(4) {
            cmd.buttons |= Action::Dodge as u32;
        }

        match (enemy_is_titan, is_titan) {
            (true, true) => cmd.weaponselect = 0, // switch to default,
            (true, false) => cmd.weaponselect = 1,
            (false, true) => cmd.weaponselect = 0, // switch to default,
            (false, false) => cmd.weaponselect = 0, // switch to default,
        }

        if is_titan && should_shoot {
            use shared::classes::TitanClass as TC;

            // for check titan class every frame
            local_data.titan = get_player_titan_class(player).unwrap_or_default();

            if let TC::Northstar = local_data.titan {
                if !should_charge {
                    // horrible!!!
                    cmd.buttons &= !(Action::Attack as u32);
                    cmd.buttons |=
                        Action::Attack as u32 * (helper.globals.frameCount % 8 >= 4) as u32;
                    cmd.buttons |= Action::Zoom as u32;
                } else {
                    cmd.buttons |= Action::Zoom as u32;
                    cmd.buttons &= !(Action::Attack as u32);
                }
            }

            cmd.buttons |= match (local_data.counter, local_data.titan) {
                (_, TC::Scorch) if distance(origin, target) <= 200. => Action::OffHand0 as u32,
                (0..60, TC::Scorch) => 0,
                (60..120, TC::Ronin | TC::Ion) => 0,
                (120..180, TC::Legion) => 0,
                (0..60, _) => Action::OffHand0 as u32,
                (60..120, _) => Action::OffHand1 as u32,
                (120..180, _) => Action::OffHand2 as u32,
                (180..240, _) => Action::OffHand3 as u32,
                (240..300, _) if should_shoot => {
                    local_data.counter = 0;
                    Action::OffHand4 as u32 // core
                }
                (240.., _) => {
                    local_data.counter = 0;
                    0
                }
            };
            local_data.counter += 1;
        }
    } else {
        if !combat_enabled { cmd.buttons |= Action::Reload as u32; }

        cmd.world_view_angles.x = 0.;
    }

    let defensive_tactical = action_policy && lookup_ent(player.m_inventory.offhandWeapons[1], helper.sv_funcs)
        .and_then(|ent| get_weaponx_name(ent, helper.sv_funcs))
        .is_some_and(|name| matches!(name, "mp_ability_heal" | "mp_ability_shifter"));
    let defensive_request = if defensive_tactical { cmd.buttons & Action::OffHand1 as u32 } else { 0 };
    if combat_enabled && !combat_target_is_titan
        && local_data.metrics.state != "embark"
        && unsafe { (helper.sv_funcs.get_pet_titan)(player) }.is_null()
        && let Some(weapon) = lookup_ent(player.m_inventory.activeWeapon, helper.sv_funcs)
            .and_then::<&CWeaponX, _>(|ent| ent.dynamic_cast())
        && let Some(name) = get_weaponx_name(weapon, helper.sv_funcs)
    {
        use crate::bots::combat_decisions::Input;
        let pos = Vector3::new(local_data.metrics.target_pos[0], local_data.metrics.target_pos[1], local_data.metrics.target_pos[2]);
        let decision = local_data.combat.decide(Input {
            now: time(helper), weapon_id: weapon.m_RefEHandle, weapon: name,
            clip: weapon.m_ammoInClip, reloading: weapon.m_bInReload,
            visible: local_data.metrics.visible, distance: distance(origin, pos),
            height: origin.z - pos.z, slot: local_data.edict,
        });
        if decision.reload { cmd.buttons |= Action::Reload as u32; }
        if decision.suppress_fire {
            cmd.buttons &= !(Action::Attack as u32 | Action::Zoom as u32 | Action::Melee as u32
                | Action::OffHand0 as u32 | Action::OffHand1 as u32 | Action::OffHand2 as u32
                | Action::OffHand3 as u32 | Action::OffHand4 as u32 | Action::OffhandQuick as u32);
            // Keep defensive intent; readiness filtering below still gates the request.
            cmd.buttons |= defensive_request;
        }
        let movement = crate::bots::switch_on(&crate::bots::COMBAT_MOVEMENT_CONVAR);
        if movement && local_data.metrics.visible && !cover_active {
            if let Some(forward) = decision.forward {
                combat_hold_move(player, helper, local_data, &mut cmd, forward);
            } else if let Some(index) = target_index {
                combat_route_move(player, helper, local_data, &mut cmd, pos, index);
            }
        } else if let Some(forward) = decision.forward {
            let state = &mut local_data.combat;
            let yaw = cmd.world_view_angles.y;
            if time(helper) >= state.step_next_at || (yaw - state.step_yaw).abs() > 40.
                || state.step_side != decision.side || state.step_forward != forward {
                state.step_next_at = time(helper) + 0.2;
                state.step_yaw = yaw;
                state.step_side = decision.side;
                state.step_forward = forward;
                let retry = crate::bots::STEP_RETRY_CONVAR.get().is_some_and(|c| c.get_value_bool());
                let side = crate::bots::action_policy::clear_side(decision.side, retry,
                    |side| combat_step_clear(player, helper, yaw, forward, side));
                state.step_clear = side.is_some();
                state.step_output_side = side.unwrap_or(0.);
                if !state.step_clear { state.blocked_steps = state.blocked_steps.saturating_add(1); }
            }
            cmd.buttons &= !(Action::Forward as u32 | Action::Back as u32 | Action::Speed as u32
                | Action::Moveleft as u32 | Action::Moveright as u32);
            cmd.move_ = if state.step_clear { Vector3::new(forward, state.step_output_side, 0.) } else { Vector3::ZERO };
            if cmd.move_.x < 0. { cmd.buttons |= Action::Back as u32; }
            if cmd.move_.y < 0. { cmd.buttons |= Action::Moveleft as u32; }
            if cmd.move_.y > 0. { cmd.buttons |= Action::Moveright as u32; }
        }
    }

    if action_policy {
        let token = unsafe { EngineToken::new_unchecked() };
        let ready = crate::bots::action_bridge::readiness(player.m_RefEHandle, token);
        let tactical_id = lookup_ent(player.m_inventory.offhandWeapons[1], helper.sv_funcs).map_or(-1, |w| w.m_RefEHandle);
        let ordnance_id = lookup_ent(player.m_inventory.offhandWeapons[0], helper.sv_funcs).map_or(-1, |w| w.m_RefEHandle);
        let tactical = local_data.tactical_pulse.press(time(helper), tactical_id,
            cmd.buttons & Action::OffHand1 as u32 != 0, ready.map(|r| r.tactical));
        // At most one pilot offhand request at once, with defensive tactical priority.
        let ordnance = local_data.ordnance_pulse.press(time(helper), ordnance_id,
            !tactical && cmd.buttons & Action::OffHand0 as u32 != 0, ready.map(|r| r.ordnance));
        if !tactical { cmd.buttons &= !(Action::OffHand1 as u32); }
        if !ordnance { cmd.buttons &= !(Action::OffHand0 as u32); }
    }
    let actions = [
        Action::OffHand0,
        Action::OffHand1,
        Action::OffHand2,
        Action::OffHand3,
        Action::OffHand4,
        Action::OffhandQuick,
    ];
    if actions
        .into_iter()
        .map(|action| action as u32)
        .any(|action| cmd.buttons & action != 0)
        && !is_titan
    {
        cmd.buttons &= !(Action::Attack as u32);
    }

    if is_timedout(local_data.next_check, helper, 10f32)
        && get_net_var(player, c"goalState", 124, helper.sv_funcs) == Some(2)
    {
        log::info!("bot calling titan down");

        let sqvm = SQVM_SERVER
            .get(unsafe { EngineToken::new_unchecked() })
            .borrow();
        if let Some(sqvm) = sqvm.as_ref() {
            call_sq_function::<(), _>(
                *sqvm,
                SQFUNCTIONS.server.wait(),
                "CodeCallback_ClientCommand",
                (
                    unsafe { UnsafeHandle::new(&*player) },
                    ["ClientCommand_RequestTitan".to_owned()],
                ),
            )
            .unwrap_or_default();
        }

        local_data.next_check = helper.globals.curTime;
    }

    local_data.metrics.neighbors = 0;
    if !is_titan && sim_type == 6 && local_data.metrics.state != "recover"
        && local_data.metrics.state != "embark" && cmd.move_.x > 0.
        && crate::bots::COORDINATION_CONVAR.get().is_some_and(|c| c.get_value_bool()) {
        let self_ptr = std::ptr::from_ref(player);
        let allies: Vec<_> = (1..=32).filter_map(|index| {
            let ptr = unsafe { (helper.sv_funcs.get_player_by_index)(index) };
            if std::ptr::addr_eq(ptr, self_ptr) { return None; }
            let ally = unsafe { ptr.as_ref()? };
            (ally.m_iTeamNum == team && ally.m_lifeState == 0 && ally.m_iHealth > 0)
                .then_some([ally.m_vecAbsOrigin.x, ally.m_vecAbsOrigin.y, ally.m_vecAbsOrigin.z])
        }).collect();
        let feet = player.m_vecAbsOrigin;
        let (side, neighbors) = crate::bots::coordination::separation_side(local_data.edict as usize,
            cmd.world_view_angles.y, [feet.x, feet.y, feet.z], &allies);
        local_data.metrics.neighbors = neighbors;
        if neighbors > 0 {
            cmd.move_.y = (cmd.move_.y + side).clamp(-1., 1.);
            local_data.metrics.spacing_commands = local_data.metrics.spacing_commands.saturating_add(1);
        }
    }
    height_followups(player, helper, local_data, &mut cmd, is_titan, sim_type);
    route_followups(player, helper, local_data, &mut cmd, is_titan, sim_type);
    cmd.camera_angles = cmd.world_view_angles;

    cmd
}

// ---- v20 candidate helpers (each gated by its own default-off switch) ----

fn v3(a: Vector3) -> [f32; 3] { [a.x, a.y, a.z] }

fn grounded(player: &mut CPlayer, helper: &CUserCmdHelper) -> bool {
    unsafe { (helper.sv_funcs.is_on_ground)(nudge_type::<&CBaseEntity>(player)) != 0 }
}

static HULL_WARNED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

/// Swept stand and duck hulls toward `dir`, using the player's own hull fields
/// and a player-collision mask (includes player clip, unlike the shot mask).
/// The bottom 18 units are ignored so ordinary steps do not read as blocked.
fn hull_fit(player: &mut CPlayer, helper: &CUserCmdHelper, dir: [f32; 2], dist: f32)
    -> crate::bots::crouch_recovery::Fit {
    use crate::bindings::{Contents, TraceCollisionGroup};
    use crate::bots::crouch_recovery::{Fit, classify, hulls_plausible};
    let stand = (v3(player.m_StandHullMin), v3(player.m_StandHullMax));
    let duck = (v3(player.m_DuckHullMin), v3(player.m_DuckHullMax));
    if !hulls_plausible(stand, duck) {
        if !HULL_WARNED.swap(true, Ordering::Relaxed) {
            log::warn!("BOT_HULL implausible stand={stand:?} duck={duck:?}; hull-based features stay inert");
        }
        return Fit::Unknown;
    }
    let len = dir[0].hypot(dir[1]);
    if !len.is_finite() || len < 0.01 || !dist.is_finite() { return Fit::Unknown; }
    let start = player.m_vecAbsOrigin + Vector3::new(0., 0., 1.);
    let end = start + Vector3::new(dir[0] / len * dist, dir[1] / len * dist, 0.);
    let mask = || Contents::SOLID | Contents::MOVEABLE | Contents::WINDOW | Contents::MONSTER
        | Contents::GRATE | Contents::PLAYER_CLIP;
    let sweep = |(min, max): ([f32; 3], [f32; 3])| {
        let trace = crate::utils::trace_hull(start, end,
            Vector3::new(min[0], min[1], min[2] + 18.), Vector3::new(max[0], max[1], max[2]),
            Some(nudge_type::<&CBaseEntity>(&*player)), TraceCollisionGroup::Player, mask(),
            helper.sv_funcs, helper.engine_funcs);
        Some((trace.fraction, trace.start_solid || trace.all_solid))
    };
    let stand_trace = sweep(stand);
    let duck_trace = sweep(duck);
    classify(stand_trace, duck_trace)
}

fn route_dir(player: &CPlayer, local: &BotData, yaw: f32) -> [f32; 2] {
    let o = player.m_vecAbsOrigin;
    let d = [local.next_target_pos.x - o.x, local.next_target_pos.y - o.y];
    if d[0].hypot(d[1]) > 4. { d } else { let (s, c) = yaw.to_radians().sin_cos(); [c, s] }
}

fn log_view_and_hulls(player: &mut CPlayer, helper: &CUserCmdHelper, local: &BotData) {
    let mut v = Vector3::ZERO;
    let view = unsafe { *(helper.sv_funcs.view_angles)(player, &mut v) };
    let eye = unsafe { *(helper.sv_funcs.get_eye_pos)(player, &mut v) };
    let stand = (v3(player.m_StandHullMin), v3(player.m_StandHullMax));
    let duck = (v3(player.m_DuckHullMin), v3(player.m_DuckHullMax));
    let o = player.m_vecAbsOrigin;
    log::info!("BOT_VIEWCHECK epoch={} slot={} eye_angles={:?} view_angles_raw={:?} eye_height={:.1} stand={stand:?} duck={duck:?} plausible={} duck_state={}",
        crate::bots::telemetry::epoch(), local.edict, v3(helper.angles), v3(view), eye.z - o.z,
        crate::bots::crouch_recovery::hulls_plausible(stand, duck) as u8, player.m_duckState);
}

fn set_move_buttons(cmd: &mut CUserCmd) {
    cmd.buttons &= !(Action::Forward as u32 | Action::Back as u32 | Action::Speed as u32
        | Action::Walk as u32 | Action::Moveleft as u32 | Action::Moveright as u32);
    if cmd.move_.x > 0. { cmd.buttons |= Action::Forward as u32; }
    if cmd.move_.x < 0. { cmd.buttons |= Action::Back as u32; }
    if cmd.move_.y < 0. { cmd.buttons |= Action::Moveleft as u32; }
    if cmd.move_.y > 0. { cmd.buttons |= Action::Moveright as u32; }
}

/// In weapon range: full-strength randomized strafes with ranked alternatives.
fn combat_hold_move(player: &mut CPlayer, helper: &CUserCmdHelper, local: &mut BotData,
    cmd: &mut CUserCmd, forward: f32) {
    let now = time(helper);
    let yaw = cmd.world_view_angles.y;
    let side = local.strafe.side(now, local.edict);
    let out = if !grounded(player, helper) {
        local.strafe.airborne_output()
    } else {
        let state = &mut local.combat;
        if now >= state.step_next_at || (yaw - state.step_yaw).abs() > 40.
            || state.step_side != side || state.step_forward != forward {
            state.step_next_at = now + 0.2;
            state.step_yaw = yaw;
            state.step_side = side;
            state.step_forward = forward;
            let choice = crate::bots::combat_movement::choose_step(forward, side,
                |f, s| combat_step_clear(player, helper, yaw, f, s));
            state.step_clear = choice.is_some();
            if choice.is_none() { state.blocked_steps = state.blocked_steps.saturating_add(1); }
            local.strafe.remember(choice.unwrap_or((0., 0.)));
        }
        local.strafe.airborne_output()
    };
    cmd.move_ = Vector3::new(out.0, out.1, 0.);
    set_move_buttons(cmd);
}

/// Out of weapon range: follow the navmesh route toward the target while the
/// aim stays on it. Movement is re-expressed relative to the aim yaw.
fn combat_route_move(player: &mut CPlayer, helper: &CUserCmdHelper, local: &mut BotData,
    cmd: &mut CUserCmd, target_pos: Vector3, target_index: usize) {
    local.route_target = local.metrics.target;
    let recalc = local.last_target_index != target_index || local.should_recalculate_path;
    if route_move_toward(player, helper, local, cmd, target_pos, recalc) {
        local.last_target_index = target_index;
    }
    local.should_recalculate_path = false;
}

/// Follow the navmesh route to `goal` while keeping the current aim; the move
/// is re-expressed relative to the aim yaw. Returns path_to_target's result.
fn route_move_toward(player: &mut CPlayer, helper: &CUserCmdHelper, local: &mut BotData,
    cmd: &mut CUserCmd, goal: Vector3, recalc: bool) -> bool {
    let aim_yaw = cmd.world_view_angles.y;
    let mut route = CUserCmd::new_basic_move(Vector3::ZERO, 0, helper);
    let routed = path_to_target(&mut route, local, player.m_vecAbsOrigin, goal, recalc, helper);
    if route.move_.x == 0. && route.move_.y == 0. { return routed; } // keep the existing input
    let (f, s) = if local.metrics.state == "recover" {
        crate::bots::combat_movement::reframe(route.move_.x, route.move_.y, route.world_view_angles.y, aim_yaw)
    } else {
        let o = player.m_vecAbsOrigin;
        let bearing = look_at(o, local.next_target_pos).y;
        if distance(o, local.next_target_pos) > 1. {
            crate::bots::combat_movement::reframe(1., 0., bearing, aim_yaw)
        } else {
            crate::bots::combat_movement::reframe(route.move_.x, route.move_.y, route.world_view_angles.y, aim_yaw)
        }
    };
    cmd.move_ = Vector3::new(f, s, 0.);
    set_move_buttons(cmd);
    // Sprint only when the route is mostly ahead of the aim; sprinting
    // sideways is not possible and would cancel the strafe component.
    if f > 0.85 { cmd.buttons |= Action::Speed as u32; }
    cmd.buttons |= route.buttons & Action::Jump as u32;
    if local.metrics.state != "recover" && local.metrics.visible { local.metrics.state = "engage"; }
    routed
}

/// `bot_height_response`: move to a nearby point the overhead enemy cannot see.
fn height_followups(player: &mut CPlayer, helper: &CUserCmdHelper, local: &mut BotData,
    cmd: &mut CUserCmd, is_titan: bool, sim_type: i32) {
    use crate::bots::height_response::{Intent, candidate_ok};
    use crate::bots::{switch_on, HEIGHT_RESPONSE_CONVAR, COMBAT_DECISIONS_CONVAR, NAV_DIAGNOSTICS_CONVAR};
    if is_titan || sim_type != 6 || !switch_on(&HEIGHT_RESPONSE_CONVAR) || !switch_on(&COMBAT_DECISIONS_CONVAR)
        || local.metrics.state == "embark" || player.m_lifeState != 0 || player.m_iHealth <= 0 {
        local.height.cancel();
        return;
    }
    let now = time(helper);
    let o = player.m_vecAbsOrigin;
    let tp = local.metrics.target_pos;
    match local.height.update(now, local.metrics.visible, tp[2] - o.z) {
        Intent::None => {}
        Intent::NeedCover => {
            let target_eye = Vector3::new(tp[0], tp[1], tp[2] + 60.);
            let mut found = None;
            let mut tried = 0;
            for _ in 0..6 {
                let Some(p) = local.nav_query.as_mut().and_then(|nav| nav.random_point_around(o, 500., Some(150.))) else { continue; };
                tried += 1;
                if !candidate_ok(v3(o), v3(p)) { continue; }
                let eye = p + Vector3::new(0., 0., 56.);
                let d = eye - target_eye;
                let len = (d.x * d.x + d.y * d.y + d.z * d.z).sqrt();
                if !len.is_finite() || len < 80. { continue; }
                // Start just outside the target so its own hitboxes do not count as cover.
                let start = target_eye + Vector3::new(d.x / len * 40., d.y / len * 40., d.z / len * 40.);
                let (fraction, _) = view_rate(helper, start, eye - GROUND_OFFSET, player, true);
                if fraction < 0.98 { found = Some(p); break; }
            }
            match found {
                Some(p) => local.height.start(now, v3(p)),
                None => local.height.none_found(now),
            }
            if switch_on(&NAV_DIAGNOSTICS_CONVAR) {
                log::info!("BOT_COVER epoch={} t={now:.2} slot={} found={} tried={tried} gap={:.0} starts={} no_cover={} x={:.1} y={:.1} z={:.1} cx={:.1} cy={:.1} cz={:.1}",
                    crate::bots::telemetry::epoch(), local.edict, found.is_some() as u8, tp[2] - o.z,
                    local.height.starts, local.height.no_cover, o.x, o.y, o.z,
                    found.map_or(0., |p| p.x), found.map_or(0., |p| p.y), found.map_or(0., |p| p.z));
            }
        }
        Intent::Cover(point) => {
            let goal = Vector3::new(point[0], point[1], point[2]);
            let recalc = local.height.take_fresh();
            local.route_target = None;
            if distance(o, goal) > 60. {
                route_move_toward(player, helper, local, cmd, goal, recalc);
            } else {
                // In cover: hold still; aim and firing remain unchanged.
                cmd.move_ = Vector3::ZERO;
                set_move_buttons(cmd);
            }
        }
    }
}

/// Crouch recovery, stall diagnostics and double jumps for route following.
fn route_followups(player: &mut CPlayer, helper: &CUserCmdHelper, local: &mut BotData,
    cmd: &mut CUserCmd, is_titan: bool, sim_type: i32) {
    use crate::bots::{switch_on, CROUCH_RECOVERY_CONVAR, NAV_DIAGNOSTICS_CONVAR, JUMP_TIMING_CONVAR};
    if !switch_on(&NAV_DIAGNOSTICS_CONVAR) && !switch_on(&CROUCH_RECOVERY_CONVAR) && !switch_on(&JUMP_TIMING_CONVAR) {
        // All three off: no native calls, no input changes (installed v19 path).
        local.stall_event = None;
        if local.crouch.is_active() || local.crouch_duck { local.crouch.cancel(); local.crouch_duck = false; }
        return;
    }
    let now = time(helper);
    let pilot_route = !is_titan && sim_type == 6 && local.navigation_requested
        && player.m_lifeState == 0 && player.m_iHealth > 0
        && local.nav_query.as_ref().is_some_and(|q| q.hull == crate::navmesh::Hull::Human);
    let on_ground = !is_titan && grounded(player, helper);
    let velocity = player.m_vecAbsVelocity;
    let speed = velocity.x.hypot(velocity.y);
    let o = player.m_vecAbsOrigin;
    let yaw = cmd.world_view_angles.y;

    if let Some(reason) = local.stall_event.take()
        && pilot_route && switch_on(&NAV_DIAGNOSTICS_CONVAR) && local.stall_log.allow(now, 0.5) {
        let dir = route_dir(player, local, yaw);
        let fit = hull_fit(player, helper, dir, 40.);
        let status = local.nav_query.as_ref().map_or(0, |n| n.last_status);
        log::info!("BOT_STALL epoch={} t={now:.2} slot={} reason={reason} state={} visible={} grounded={} speed={speed:.0} corner_flags={} corner_jump={} next_dist={:.0} next_dz={:.1} partial={} fit={fit:?} duck_state={} x={:.1} y={:.1} z={:.1}",
            crate::bots::telemetry::epoch(), local.edict, local.metrics.state, local.metrics.visible as u8,
            on_ground as u8, local.current_corner.map_or(-1, |m| m.0 as i32),
            local.current_corner.map_or(-1, |m| m.1 as i32), distance(local.next_target_pos, o),
            local.next_target_pos.z - o.z, crate::bots::nav_diagnostics::is_partial(status) as u8,
            player.m_duckState, o.x, o.y, o.z);
    }

    if switch_on(&CROUCH_RECOVERY_CONVAR) && pilot_route && local.metrics.state != "recover" {
        use crate::bots::crouch_recovery::Intent;
        let commanding = cmd.move_.x.hypot(cmd.move_.y) > 0.3;
        let dir = route_dir(player, local, yaw);
        let mut tested = None;
        let intent = local.crouch.update(now, [o.x, o.y], on_ground, speed, commanding, || {
            let fit = hull_fit(player, helper, dir, 40.);
            tested = Some(fit);
            fit
        });
        if intent == Intent::Crouch {
            cmd.buttons &= !(Action::Speed as u32 | Action::Jump as u32);
            cmd.buttons |= Action::Duck as u32;
            cmd.move_.z = 0.;
        }
        let duck = intent == Intent::Crouch;
        if switch_on(&NAV_DIAGNOSTICS_CONVAR) && (tested.is_some() || duck != local.crouch_duck || intent == Intent::Failed) {
            log::info!("BOT_CROUCH epoch={} t={now:.2} slot={} intent={intent:?} fit={:?} duck={} duck_state={} attempts={} successes={} failures={} x={:.1} y={:.1} z={:.1}",
                crate::bots::telemetry::epoch(), local.edict, tested, duck as u8, player.m_duckState,
                local.crouch.attempts, local.crouch.successes, local.crouch.failures, o.x, o.y, o.z);
        }
        local.crouch_duck = duck;
    } else if local.crouch.is_active() || local.crouch_duck {
        local.crouch.cancel();
        local.crouch_duck = false;
    }

    if switch_on(&JUMP_TIMING_CONVAR) && !is_titan && sim_type == 6 {
        let wanted = local.jump_timing.double_jump(now, on_ground,
            local.next_target_pos.z - o.z, distance(local.next_target_pos, o));
        if wanted && pilot_route && local.metrics.state != "recover" && !local.crouch_duck {
            cmd.buttons |= Action::Jump as u32;
        }
    }
}

/// Small grounded steps only; tracing is cached at 5 Hz, outside navigation.
fn combat_step_clear(player: &mut CPlayer, helper: &CUserCmdHelper, yaw: f32, forward: f32, side: f32) -> bool {
    if !yaw.is_finite() || unsafe { (helper.sv_funcs.is_on_ground)(nudge_type::<&CBaseEntity>(player)) } == 0 { return false; }
    let (sin, cos) = yaw.to_radians().sin_cos();
    // Positive side movement is right in Source's command coordinates.
    let direction = Vector3::new(cos * forward + sin * side, sin * forward - cos * side, 0.);
    let length = (direction.x * direction.x + direction.y * direction.y).sqrt();
    if length < 0.01 { return false; }
    let start = player.m_vecAbsOrigin + Vector3::new(0., 0., 32.);
    let end = start + Vector3::new(direction.x * 64. / length, direction.y * 64. / length, 0.);
    // view_rate adds GROUND_OFFSET internally; subtract it to trace exact endpoints.
    let (wall, _) = view_rate(helper, start, end - GROUND_OFFSET, player, true);
    if wall < 0.98 { return false; }
    let (ground, _) = view_rate(helper, end, end - Vector3::new(0., 0., 104.) - GROUND_OFFSET, player, true);
    ground > 0.01 && ground < 0.95
}

unsafe fn find_team_target<'a>(
    origin: Vector3, team: i32, player: &mut CPlayer, helper: &CUserCmdHelper,
    local: &BotData, coordinator: &crate::bots::coordination::Coordinator,
) -> Option<((Vector3, &'a mut CPlayer), bool)> {
    use crate::bots::coordination::Candidate;
    struct NativeTarget { candidate: Candidate, pos: Vector3, player: *mut CPlayer }
    let mut v = Vector3::ZERO;
    let view = unsafe { *(helper.sv_funcs.view_angles)(player, &mut v) };
    let filter_pet = crate::bots::TARGET_ELIGIBILITY_CONVAR.get().is_some_and(|c| c.get_value_bool());
    let token = unsafe { EngineToken::new_unchecked() };
    let targets: Vec<_> = enemy_player_iterator(team, helper).map(|t| (t, false))
        .chain(enemy_titan_iterator(helper, team).map(|t| (t, true)))
        .filter(|(target, pet)| target.m_RefEHandle != -1 && (!filter_pet || !pet
            || crate::bots::action_bridge::target_allowed(target.m_RefEHandle, time(helper), token)))
        .map(|(target, _)| {
            let pos = unsafe { *target.get_origin(&mut v) };
            NativeTarget { candidate: Candidate { id: target.m_RefEHandle, distance: distance(pos, origin) },
                pos, player: std::ptr::from_mut(target) }
        }).collect();
    let candidates: Vec<_> = targets.iter().map(|t| t.candidate).collect();
    let ranked = coordinator.rank(local.edict as usize, team, time(helper), &candidates);
    // Prefer a shootable threat in team-aware order. A failed raycast never
    // reserves a target or prevents checking the remaining visible enemies.
    let perception = crate::bots::switch_on(&crate::bots::PERCEPTION_FIX_CONVAR);
    let eye = if perception { unsafe { *(helper.sv_funcs.get_eye_pos)(player, &mut v) } } else { origin };
    let visible = ranked.iter().copied().find(|index| {
        let target = &targets[*index];
        if target.candidate.distance > BOT_VISON_RANGE { return false; }
        let (from, to) = if perception {
            // Facing from known eye angles; sight line eye-to-target-upper-body,
            // which is also the line the existing aim sends shots along.
            let to = target.pos + Vector3::new(0., 0., crate::bots::perception::target_sight_height(
                unsafe { (&*target.player).m_Collision.m_vecMaxs.z }));
            if !crate::bots::perception::in_front_hemisphere(helper.angles.y,
                [to.x - eye.x, to.y - eye.y, to.z - eye.z]) { return false; }
            // view_rate adds GROUND_OFFSET to the end point; remove it for an exact line.
            (eye, to - GROUND_OFFSET)
        } else {
            if dot(normalize(target.pos - origin), view) <= 270_f32.to_radians().cos() { return false; }
            (origin, target.pos)
        };
        let (fraction, hit) = view_rate(helper, from, to, target.player, false);
        if fraction != 1. && !std::ptr::addr_eq(hit, target.player) { return false; }
        let (fraction, hit) = view_rate(helper, from, to, target.player, true);
        fraction == 1. || std::ptr::addr_eq(hit, target.player)
    });
    // Pursuit (not engagement) skips a target whose routes keep ending far
    // short of it, so bots stop circling under unreachable positions.
    let pursue = if crate::bots::switch_on(&crate::bots::ROUTE_GUARD_CONVAR) {
        ranked.iter().copied().find(|i| !local.unreachable.blocks(time(helper), targets[*i].candidate.id))
            .or_else(|| ranked.first().copied())
    } else { ranked.first().copied() };
    let selected = visible.or(pursue)?;
    let selected = &targets[selected];
    Some(((selected.pos, unsafe { selected.player.as_mut()? }), visible.is_some()))
}

fn find_closest_battery(pos: Vector3, helper: &CUserCmdHelper) -> Option<Vector3> {
    let token = try_refresh_headhunter(helper);

    unsafe { &*HEADHUNTER_DATA.get(token).get() }
        .batteries
        .iter()
        .map(|this| (*this, distance(pos, *this)))
        .reduce(|closer, other| if closer.1 < other.1 { closer } else { other })
        .map(|(pos, _)| pos)
}

fn find_closest_hardpoint(pos: Vector3, helper: &CUserCmdHelper) -> Vector3 {
    let token = try_refresh_headhunter(helper);

    unsafe { &*HEADHUNTER_DATA.get(token).get() }
        .hardpoints
        .iter()
        .map(|this| (*this, distance3(pos, *this)))
        .reduce(|closer, other| if closer.1 < other.1 { closer } else { other })
        .map(|(pos, _)| pos)
        .unwrap_or_else(|| {
            log::warn!("no hardpoints found");
            Vector3::ZERO
        })
}

fn find_flag_for(
    team: i32,
    match_team: bool,
    player_index: u32,
    helper: &CUserCmdHelper,
) -> (Vector3, bool) {
    let token = try_refresh_ctf(helper);

    unsafe { &*CTF_DATA.get(token).get() }
        .flags
        .iter()
        .find(|(_, flag_team, _)| (*flag_team == team) == match_team)
        .copied()
        .map(|(pos, _, parent)| (pos, parent == player_index))
        .unwrap_or(Default::default())
}

fn find_base_for(team: i32, match_team: bool, helper: &CUserCmdHelper) -> Vector3 {
    let token = try_refresh_ctf(helper);

    unsafe { &*CTF_DATA.get(token).get() }
        .bases
        .iter()
        .find(|(_, flag_team)| (*flag_team == team) == match_team)
        .copied()
        .map(|(pos, _)| pos)
        .unwrap_or(Default::default())
}

fn try_refresh_headhunter(helper: &CUserCmdHelper) -> EngineToken {
    let token = unsafe { EngineToken::new_unchecked() };
    let data = unsafe { &mut *HEADHUNTER_DATA.get(token).get() };
    let mut v = Vector3::ZERO;

    if data.last_checked == helper.globals.frameCount {
        return token;
    }
    data.last_checked = helper.globals.frameCount;

    data.batteries.clear();
    data.hardpoints.clear(); // hmm

    data.batteries.extend(
        get_ents_by_class_name(c"item_titan_battery", helper.sv_funcs)
            .filter(|ent| unsafe { (helper.sv_funcs.get_parent)((*ent).cast_const()).is_null() })
            .map(|ent| unsafe {
                // the vtable is the almost the same so it's safe
                *ent.cast::<CPlayer>()
                    .as_ref()
                    .unwrap_unchecked()
                    .get_origin(&mut v)
            }),
    );
    data.hardpoints.extend(
        get_ents_by_class_name(c"info_hardpoint", helper.sv_funcs).map(|ent| unsafe {
            *ent.cast::<CPlayer>()
                .as_ref()
                .unwrap_unchecked()
                .get_origin(&mut v)
        }),
    );

    token
}

fn try_refresh_ctf(helper: &CUserCmdHelper) -> EngineToken {
    let token = unsafe { EngineToken::new_unchecked() };
    let data = unsafe { &mut *CTF_DATA.get(token).get() };
    let mut v = Vector3::ZERO;

    if data.last_checked == helper.globals.frameCount {
        return token;
    }
    data.last_checked = helper.globals.frameCount;

    data.bases.clear();
    data.flags.clear(); // hmm

    data.bases.extend(
        get_ents_by_class_name(c"info_spawnpoint_flag", helper.sv_funcs).map(|ent| unsafe {
            (
                *ent.as_ref().unwrap_unchecked().get_origin(&mut v),
                ent.as_ref().unwrap_unchecked().m_iTeamNum,
            )
        }),
    );
    data.flags.extend(
        get_ents_by_class_name(c"item_flag", helper.sv_funcs).map(|ent| unsafe {
            (
                *ent.as_ref().unwrap_unchecked().get_origin(&mut v),
                ent.as_ref().unwrap_unchecked().m_iTeamNum,
                (helper.sv_funcs.get_parent)(ent.cast_const())
                    .as_ref()
                    .and_then::<&CPlayer, _>(|parent| parent.dynamic_cast())
                    .map(|parent| get_player_index(parent) as u32)
                    .unwrap_or(u32::MAX),
            )
        }),
    );

    token
}

// fn generate_spread(dir: Vector3) -> Vec<Vector3> {
//     dbg!("wow");
//     let dir = normalize(dir);
//     (0..20i32)
//         .map(|i| i.saturating_sub(1) as f32)
//         .map(|i| dir * Vector3::new(i, i, 0.))
//         .map(|angle| Vector3::new(angle.x.clamp(-10., 10.), angle.y.clamp(-10., 10.), 0.))
//         .collect()
// }

#[allow(dead_code)]
fn generate_spread(dir: Vector3, buffer: &mut [Vector3]) {
    dbg!("wow");
    let dir = normalize(dir);
    let spread = (0..50)
        .map(|i| i as f32 / 25.)
        .map(|i| dir * Vector3::new(i, i, 0.))
        .map(|angle| Vector3::new(angle.x.clamp(-4., 4.), angle.y.clamp(-4., 4.), 0.));

    buffer
        .iter_mut()
        .zip(spread)
        .for_each(|(buffer, offset)| *buffer = offset);
}
