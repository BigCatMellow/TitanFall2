//! Own both output buffers for the engine's modified Detour findPath ABI.
//!
//! The engine writes one u32 polygon reference AND one u8 traversal type per
//! result. Both allocations must cover maxPath, including on repeated queries.

#[derive(Debug, PartialEq, Eq)]
pub(super) struct InvalidPathCount {
    pub count: u32,
    pub capacity: usize,
}

pub(super) fn fill_path_buffers<T>(
    path: &mut Vec<u32>,
    jumps: &mut Vec<u8>,
    fill: impl FnOnce(&mut [u32], &mut [u8], &mut u32) -> T,
) -> Result<T, InvalidPathCount> {
    let capacity = path.capacity().min(jumps.capacity()).min(i32::MAX as usize);
    path.resize(capacity, 0);
    jumps.resize(capacity, u8::MAX);
    let mut count = 0;
    let status = fill(path, jumps, &mut count);
    if count as usize > capacity {
        path.clear();
        jumps.clear();
        return Err(InvalidPathCount { count, capacity });
    }
    path.truncate(count as usize);
    jumps.truncate(count as usize);
    Ok(status)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Model the two native output writes at server.dll+0x3ec96b/0x3ec974.
    // A route longer than eight polygons overflowed the old i64 stack slot.
    fn native_find_path(path: &mut [u32], jumps: &mut [u8], count: &mut u32, steps: usize) {
        assert_eq!(path.len(), jumps.len());
        assert!(steps <= path.len());
        unsafe {
            for i in 0..steps {
                path.as_mut_ptr().add(i).write(i as u32 + 1);
                jumps.as_mut_ptr().add(i).write((i % 21) as u8);
            }
        }
        *count = steps as u32;
    }

    #[test]
    fn full_256_step_route_has_two_complete_output_buffers() {
        let mut path = Vec::with_capacity(256);
        let mut jumps = Vec::with_capacity(256);
        fill_path_buffers(&mut path, &mut jumps, |p, j, count| {
            native_find_path(p, j, count, 256);
        }).unwrap();
        assert_eq!(path, (1..=256).collect::<Vec<u32>>());
        assert_eq!(jumps, (0..256).map(|i| (i % 21) as u8).collect::<Vec<_>>());
    }

    #[test]
    fn short_then_long_queries_restore_both_buffer_lengths() {
        let mut path = Vec::with_capacity(256);
        let mut jumps = Vec::with_capacity(256);
        for steps in [1, 8, 9, 100, 3, 256, 0, 32] {
            fill_path_buffers(&mut path, &mut jumps, |p, j, count| {
                native_find_path(p, j, count, steps);
            }).unwrap();
            assert_eq!(path.len(), steps);
            assert_eq!(jumps.len(), steps);
            assert_eq!(path.last().copied(), (steps > 0).then_some(steps as u32));
        }
    }

    #[test]
    fn uses_smaller_output_capacity_and_rejects_invalid_native_count() {
        let mut path = Vec::with_capacity(256);
        let mut jumps = Vec::with_capacity(16);
        let error = fill_path_buffers(&mut path, &mut jumps, |p, j, count| {
            assert_eq!(p.len(), 16);
            assert_eq!(j.len(), 16);
            *count = 17;
        }).unwrap_err();
        assert_eq!(error, InvalidPathCount { count: 17, capacity: 16 });
        assert!(path.is_empty());
        assert!(jumps.is_empty());
    }
}
