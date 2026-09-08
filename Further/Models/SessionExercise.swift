import Foundation
import SwiftData

/// An exercise performed within a Session.
///
/// `exerciseId` references a bundled `Exercise` (by slug). `exerciseNameSnapshot`
/// preserves the display name at the time the set was logged, so historical
/// sessions read correctly even if the bundled DB is updated in a future app
/// version.
///
/// `targetRepsMin`/`Max` snapshot the source `WorkoutExercise`'s target range
/// at session-start time. Used to display "Target: 3 × 8–10" in the Active
/// Workout header. Snapshotted (rather than looked up) so the target stays
/// stable even if the source Workout is edited mid-session.
@Model
final class SessionExercise {
    var id: UUID = UUID()
    var exerciseId: String = ""
    var exerciseNameSnapshot: String = ""
    var displayOrder: Int = 0

    var targetSets: Int = 0
    var targetRepsMin: Int = 0
    var targetRepsMax: Int = 0

    var session: Session?

    @Relationship(deleteRule: .cascade, inverse: \WorkSet.sessionExercise)
    var sets: [WorkSet]? = []

    init(
        exerciseId: String = "",
        exerciseNameSnapshot: String = "",
        displayOrder: Int = 0,
        targetSets: Int = 0,
        targetRepsMin: Int = 0,
        targetRepsMax: Int = 0
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.displayOrder = displayOrder
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.sets = []
    }
}
