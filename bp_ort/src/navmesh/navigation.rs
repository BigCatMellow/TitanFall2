#![deny(clippy::unwrap_used, clippy::expect_used)]
use rand::Rng;
use rrplug::prelude::*;
use std::mem::MaybeUninit;
use thiserror::Error;

use super::{
    Hull, JumpTypes, RECAST_DETOUR, RecastDetour,
    bindings::{dtNavMeshQuery, dtPolyRef, dtQueryFilter},
    path_buffers::fill_path_buffers,
};

const HUMAN_EXTENTS: Vector3 = Vector3::new(100.0, 100.0, 136.0);
const TITAN_EXTENTS: Vector3 = Vector3::new(200.0, 200.0, 500.0);
const TARGET_EXTENTS: Vector3 = Vector3::new(200.0, 200.0, 500.0);
const PATH_CAPACITY: usize = 256;

#[derive(Error, Debug)]
pub enum NavigationError {
    #[error("failed to find nearest poly, with start {0:?}({2}) and end {1:?}({3})")]
    NoPoints(Vector3, Vector3, u32, u32),

    #[error("path not found between {0:?} and {1:?}")]
    PathNotFound(Vector3, Vector3),

    #[error("native pathfinder returned an invalid output count")]
    InvalidOutputCount,
}

#[derive(Debug)]
pub struct Navigation {
    query: dtNavMeshQuery,
    extents: &'static Vector3,
    pub hull: Hull,
    pub filter: dtQueryFilter,
    path: Vec<dtPolyRef>,
    pub path_points: Vec<Vector3>,
    pub end_point: Option<Vector3>,
    /// Per remaining point (same order as `path_points`): straight-path flag and
    /// native traversal/jump type, when the native straight path supplied them.
    pub corner_meta: Vec<(u8, u8)>,
    /// Raw status of the most recent findPath call (diagnostics/route guard).
    pub last_status: u32,
    /// Projected end point of the most recent route, if any.
    pub last_end: Option<Vector3>,
    jump_types: Vec<u8>,
    straigth_path_points: Vec<Vector3>,
    straigth_path: Vec<dtPolyRef>,
    straigth_path_flags: Vec<u8>,
    straigth_path_jumps: Vec<u8>,
}

impl Navigation {
    pub fn new(hull: Hull) -> Option<Self> {
        Some(Self {
            query: generate_nav_query(hull, None)?,
            extents: hull_to_extents(hull),
            hull,
            filter: dtQueryFilter {
                m_areaCost: if hull == Hull::Human {
                    // [
                    //     1621.6901, 1274.1852, 1698.9136, 1158.3501, 1814.7485, 2123.6418, 0.0, 0.0,
                    //     3243.3801, 2123.6418, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    //     2123.6418, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    // ]
                    [0.0; 32]
                } else {
                    Default::default()
                },
                m_includeFlags: u16::MAX,
                m_excludeFlags: 0,
                m_traverseFlags: (JumpTypes::SmallObjectsCrossing.into_u32()
                    | JumpTypes::CratesTraversal.into_u32()
                    | JumpTypes::ShortWallTraversal.into_u32()
                    | JumpTypes::ShortJumpsAcrossSameLevel.into_u32())
                    * (hull == Hull::Human) as u32,
            },
            path: Vec::with_capacity(PATH_CAPACITY),
            path_points: Vec::with_capacity(PATH_CAPACITY),
            end_point: None,
            corner_meta: Vec::with_capacity(PATH_CAPACITY),
            last_status: 0,
            last_end: None,
            jump_types: vec![u8::MAX; PATH_CAPACITY],
            straigth_path: Vec::with_capacity(PATH_CAPACITY),
            straigth_path_points: Vec::with_capacity(PATH_CAPACITY),
            straigth_path_flags: Vec::with_capacity(PATH_CAPACITY),
            straigth_path_jumps: Vec::with_capacity(PATH_CAPACITY),
        })
    }

    pub fn switch_query(&mut self, hull: Hull) -> Option<()> {
        self.path.clear();
        self.path_points.clear();

        self.query = generate_nav_query(hull, Some(&self.query))?;
        self.extents = hull_to_extents(hull);
        self.hull = hull;

        Some(())
    }

    pub fn new_path(
        &mut self,
        start_point: Vector3,
        end_point: Vector3,
        dt_funcs: &RecastDetour,
    ) -> Result<(), NavigationError> {
        let mut ref_start = 0;
        let mut start = Vector3::ZERO;
        let mut ref_end = 0;
        let mut end = Vector3::ZERO;

        self.end_point = None;
        self.path_points.clear();
        self.corner_meta.clear();
        self.last_status = 0;
        self.last_end = None;

        let status = unsafe {
            if (dt_funcs.dtNavMeshQuery__findNearestPoly)(
                &mut self.query,
                &start_point,
                self.extents,
                &self.filter,
                &mut ref_start,
                &mut start,
            ) == 0x40000000
            {
                (dt_funcs.dtNavMeshQuery__findNearestPoly)(
                    &mut self.query,
                    &end_point,
                    &TARGET_EXTENTS,
                    &self.filter,
                    &mut ref_end,
                    &mut end,
                ) == 0x40000000
            } else {
                false
            }
        };

        if !status || ref_end == 0 || ref_start == 0 {
            log::warn!("failed to find nearest poly, with goal {ref_end} start {ref_start}");
            return Err(NavigationError::NoPoints(start_point, end_point, ref_start, ref_end));
        }

        // Titanfall's Detour ABI has TWO variable-sized outputs. The former
        // eight-byte `unk` stack slot was overwritten by routes > 8 polygons.
        let status = fill_path_buffers(
            &mut self.path,
            &mut self.jump_types,
            |path, jumps, count| unsafe {
                (dt_funcs.dtNavMeshQuery__findPath)(
                    &mut self.query,
                    ref_start,
                    ref_end,
                    &start,
                    &end,
                    &self.filter,
                    path.as_mut_ptr(),
                    jumps.as_mut_ptr(),
                    count,
                    path.len() as i32,
                )
            },
        ).map_err(|_| NavigationError::InvalidOutputCount)?;
        let path_size = self.path.len();
        self.path_points.clear();
        self.last_status = status;

        if status & 0x40000000 == 0 || path_size == 0 {
            return Err(NavigationError::PathNotFound(start, end));
        }

        self.end_point = Some(end_point);

        let mut straight_size = 0;
        unsafe {
            (dt_funcs.dtNavMeshQuery__findStraightPath)(
                &mut self.query,
                &start,
                &end,
                self.path.as_ptr(),
                self.jump_types.as_ptr(),
                path_size as i32,
                self.straigth_path_points.as_mut_ptr(),
                self.straigth_path_flags.as_mut_ptr(),
                self.straigth_path.as_mut_ptr(),
                self.straigth_path_jumps.as_mut_ptr(),
                &mut straight_size,
                PATH_CAPACITY as i32,
                0,
                0,
            );
        }

        if straight_size < 0 || straight_size as usize > PATH_CAPACITY {
            return Err(NavigationError::InvalidOutputCount);
        }
        if straight_size != 0 {
            unsafe {
                self.straigth_path_jumps.set_len(straight_size as usize);
                self.straigth_path_points.set_len(straight_size as usize);
                self.straigth_path.set_len(straight_size as usize);
                self.straigth_path_flags.set_len(straight_size as usize);
                self.straigth_path_points.clone_into(&mut self.path_points);
                // The native straight path already ends at a reachable point.
                // Appending an airborne/raw target bypasses that projection,
                // particularly when findPath returned a partial corridor.
                self.path_points.reverse();
                self.corner_meta.clear();
                self.corner_meta.extend(self.straigth_path_flags.iter().copied()
                    .zip(self.straigth_path_jumps.iter().copied()));
                self.corner_meta.reverse();
                self.straigth_path.clone_into(&mut self.path);
            }
        } else if path_size == 1 {
            self.path_points.push(end);
            self.path_points.push(start);
        } else {
            let mut prev_point = start;
            self.path
                .iter()
                .cloned()
                .map(|polyref| (polyref, Vector3::ZERO))
                .map(|(next_ref, mut next_point)| {
                    unsafe {
                        (dt_funcs.dtNavMeshQuery__closestPointOnPolyBoundary__variant)(
                            &self.query,
                            next_ref,
                            &prev_point,
                            &mut next_point,
                            &self.filter,
                        );
                        // let mut tile = std::ptr::null_mut();
                        // let mut poly = std::ptr::null_mut();
                        // (dt_funcs.dtNavMesh__)(self.query.nav, next_ref, &mut tile, &mut poly);

                        // let poly = poly.as_mut().unwrap();
                    }
                    prev_point = next_point;
                    next_point
                })
                .rev()
                .collect_into(&mut self.path_points);
        }
        // Points are consumed from the back, so the first element is the end.
        self.last_end = self.path_points.first().copied();

        Ok(())
    }

    pub fn next_point(&mut self) -> Option<Vector3> {
        self.next_corner().map(|(point, _)| point)
    }

    /// Pops the next point with its straight-path metadata. Metadata is only
    /// returned while it is still aligned with `path_points`; callers elsewhere
    /// clear `path_points` directly, which drops the alignment rather than
    /// misattributing a stale traversal type.
    pub fn next_corner(&mut self) -> Option<(Vector3, Option<(u8, u8)>)> {
        let aligned = self.corner_meta.len() == self.path_points.len();
        let point = self.path_points.pop()?;
        let meta = if aligned { self.corner_meta.pop() } else { self.corner_meta.clear(); None };
        Some((point, meta))
    }

    pub fn random_point_around(
        &mut self,
        point: Vector3,
        radius: f32,
        min_radius: Option<f32>,
    ) -> Option<Vector3> {
        const MAX_RANDOM_POINTS: usize = 65; // the game uses this amount
        let funcs = RECAST_DETOUR.wait();

        let len = MAX_RANDOM_POINTS.min(self.straigth_path_points.capacity());
        if unsafe {
            (funcs.dtFreeNavMeshQuery_findRandomPointsAroundCircle)(
                &mut self.query,
                &point,
                min_radius.unwrap_or(100f32).min(radius),
                radius,
                &self.filter,
                funcs.some_non_function_function,
                funcs.dtfrand,
                // straigth_path_points is only used as tmp storage so this won't break anything
                len as u32,
                self.straigth_path_points.as_mut_ptr(),
            )
        } == 0x40000000
        {
            // SAFETY: the function should have filled every point
            unsafe {
                self.straigth_path_points.set_len(len);
            }
            self.straigth_path_points
                .get(rand::thread_rng().gen_range(0..self.straigth_path_points.len()))
                .copied()
        } else {
            None
        }
    }
}

impl Drop for Navigation {
    fn drop(&mut self) {
        unsafe { (RECAST_DETOUR.wait().dtFreeNavMeshQuery_Destroy)(&mut self.query) }
    }
}

fn generate_nav_query(hull: Hull, prev_query: Option<&dtNavMeshQuery>) -> Option<dtNavMeshQuery> {
    let mut query = prev_query
        .map(|query| MaybeUninit::new(query.clone()))
        .unwrap_or_else(MaybeUninit::zeroed);

    let dt_funcs = RECAST_DETOUR.wait();

    unsafe {
        (dt_funcs.ZeroOutdtNavMesh)(query.as_mut_ptr());
        let hull_index = (dt_funcs.GetNavMeshHullIndex)(hull as i32);

        if (dt_funcs.dtNavMeshQuery__init)(
            query.as_mut_ptr(),
            *dt_funcs.nav_mesh.add(hull_index as usize).as_ref()?,
            2048,
        ) != 0x40000000
        {
            return None;
        }
    }

    Some(unsafe { query.assume_init() })
}

fn hull_to_extents(hull: Hull) -> &'static Vector3 {
    match hull {
        Hull::Human => &HUMAN_EXTENTS,
        Hull::Medium => &HUMAN_EXTENTS,
        Hull::FlyingVehicle => &TITAN_EXTENTS,
        Hull::Small => &HUMAN_EXTENTS,
        Hull::Titan => &TITAN_EXTENTS,
    }
}
