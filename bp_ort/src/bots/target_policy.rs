//! Reversible pursuit-distance selection for bots without a visible enemy.
//! Existing fallback is farthest-first; the opt-in path is nearest-first.
//! Coordinate-based viability still belongs to the navigation subsystem.
pub(super) fn select_distance<T>(
    candidates: impl Iterator<Item = (i64, T)>,
    nearest: bool,
) -> Option<(i64, T)> {
    candidates.filter(|(distance, _)| *distance >= 0).reduce(|best, candidate| {
        if (nearest && candidate.0 < best.0) || (!nearest && candidate.0 > best.0) {
            candidate
        } else {
            best
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn fallback_preserves_farthest_until_explicitly_enabled() {
        let options = || [(900, 1), (150, 2), (500, 3)].into_iter();
        assert_eq!(select_distance(options(), false), Some((900, 1)));
        assert_eq!(select_distance(options(), true), Some((150, 2)));
    }
    #[test]
    fn ties_stay_stable_and_invalid_distances_do_not_win() {
        assert_eq!(select_distance([(200, 1), (200, 2)].into_iter(), true), Some((200, 1)));
        assert_eq!(select_distance([(-1, 1), (350, 2)].into_iter(), true), Some((350, 2)));
        assert_eq!(select_distance(std::iter::empty::<(i64, i32)>(), true), None);
    }
}
