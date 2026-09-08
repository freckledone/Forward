import Foundation
import SwiftData

/// An exercise slot within a Workout — the exercise, its set count, and the
/// rep range target.
///
/// Formerly `TemplateExercise`. Renamed per D-047. Same semantics.
///
/// `exerciseId` is a stable string slug referring to a bundled `Exercise`
/// value type (D-031). It is NOT a SwiftData `@Relationship`, because
/// `Exercise` is not a SwiftData model.
///
/// Rep targets are stored as a min/max Int pair per D-039. When `min == max`,
/// the UI displays a single number ("5"); when they differ, a range ("6–8").
@Model
final class WorkoutExercise {
    var id: UUID = UUID()
    var exerciseId: String = ""
    var displayOrder: Int = 0
    var targetSets: Int = 0
    var targetRepsMin: Int = 0
    var targetRepsMax: Int = 0
    var workout: Workout?

    init(
        exerciseId: String = "",
        displayOrder: Int = 0,
        targetSets: Int = 0,
        targetRepsMin: Int = 0,
        targetRepsMax: Int = 0
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.displayOrder = displayOrder
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
    }
}
