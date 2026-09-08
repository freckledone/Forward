import Foundation

/// Produces a suggested weight+reps for a given set of an exercise, based on
/// the user's history.
///
/// Per D-006, `SuggestionEngine` is a protocol so the algorithm can evolve
/// independently of UI. The Active Workout view depends only on this
/// protocol; the concrete implementation is swappable.
protocol SuggestionEngine {
    /// - Parameters:
    ///   - exerciseId: bundled Exercise slug
    ///   - setIndex: 0-based index of the set within the current exercise
    ///   - history: past `SessionExercise` records for THIS exerciseId,
    ///     ordered most-recent-first. Caller filters and sorts.
    /// - Returns: a suggested set, or nil if no basis for a suggestion exists.
    func suggest(
        for exerciseId: String,
        setIndex: Int,
        history: [SessionExercise]
    ) -> SuggestedSet?
}

struct SuggestedSet: Equatable, Hashable {
    let weightKg: Double
    let reps: Int
}

/// V1 implementation (D-007).
///
/// Pre-fills each set with what the user did in the same slot of the most
/// recent completed session of the same exercise. No auto-adjustment. Zero
/// risk of being wrong; puts progression decisions in the user's hands and
/// forces the "bump weight" UI to be fast.
struct LastSessionSuggestionEngine: SuggestionEngine {
    func suggest(
        for exerciseId: String,
        setIndex: Int,
        history: [SessionExercise]
    ) -> SuggestedSet? {
        guard let last = history.first(where: { $0.exerciseId == exerciseId }) else {
            return nil
        }
        let sets = (last.sets ?? [])
            .filter { $0.completedAt != nil && !$0.skipped }
            .sorted { $0.order < $1.order }
        guard setIndex < sets.count else { return nil }
        let s = sets[setIndex]
        return SuggestedSet(weightKg: s.weightKg, reps: s.reps)
    }
}
