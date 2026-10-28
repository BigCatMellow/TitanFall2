use rrplug::{
    high::squirrel::{UserData, UserDataRef},
    prelude::*,
};

use crate::navmesh::{
    Hull, RECAST_DETOUR,
    navigation::{Navigation, NavigationError},
};

pub fn navigation_register_sq_functions() {
    register_sq_functions(navigation_new);
    register_sq_functions(navigation_find_path);
    register_sq_functions(navigation_get_all_points);
    register_sq_functions(navigation_next_point);
    register_sq_functions(navigation_random_point);
    register_sq_functions(navigation_research_query);
    register_sq_functions(navigation_research_report);
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationResearchQuery")]
fn navigation_research_query(hull: Hull, node_budget: i32, uniform_cost: bool, excluded_traversals: i32) -> Option<UserData<Navigation>> {
    Some(UserData::new(Navigation::research_query(hull, node_budget, uniform_cost, excluded_traversals)?))
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationResearchReport")]
fn navigation_research_report(nav: UserDataRef<Navigation>) -> String {
    let gap = nav.last_end.zip(nav.projected_goal).map_or(-1., |(a,b)| {
        ((a.x-b.x).powi(2)+(a.y-b.y).powi(2)+(a.z-b.z).powi(2)).sqrt()
    });
    let corners = nav.path_points.iter().rev().take(8).enumerate().map(|(i,p)| {
        let meta = nav.corner_meta.iter().rev().nth(i).copied();
        format!("{:.1},{:.1},{:.1},{},{}",p.x,p.y,p.z,meta.map_or(-1,|m|m.0 as i32),meta.map_or(-1,|m|m.1 as i32))
    }).collect::<Vec<_>>().join(";");
    format!("status={:#x} straight_status={:#x} reached_poly={} polys={} points={} projected_gap={:.1} corners={}",
        nav.last_status,nav.straight_status,nav.reached_goal_poly as u8,nav.corridor_poly_count,nav.path_points.len(),gap,corners)
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationCreate")]
fn navigation_new(hull: Hull) -> Option<UserData<Navigation>> {
    Some(UserData::new(Navigation::new(hull)?))
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationFindPath")]
fn navigation_find_path(
    mut nav: UserDataRef<Navigation>,
    start: Vector3,
    end: Vector3,
) -> Result<(), NavigationError> {
    nav.new_path(start, end, RECAST_DETOUR.wait())
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationGetAllPoints")]
fn navigation_get_all_points(nav: UserDataRef<Navigation>) -> Vec<Vector3> {
    nav.path_points.clone()
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationNextPoint")]
fn navigation_next_point(mut nav: UserDataRef<Navigation>) -> Option<Vector3> {
    nav.next_point()
}

#[rrplug::sqfunction(VM = "SERVER", ExportName = "NavigationRandomPoint")]
fn navigation_random_point(
    mut nav: UserDataRef<Navigation>,
    center: Vector3,
    radius: f32,
) -> Option<Vector3> {
    nav.random_point_around(center, radius, None)
}
