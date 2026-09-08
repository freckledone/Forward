import Foundation
import SwiftData

/// A workout instance — in-progress OR completed (D-029).
///
/// - `endedAt == nil` marks an in-progress session; the Home resume banner
///   queries for this state.
/// - `workoutId` is a weak reference to the source Workout. If the Workout is
///   deleted, `workoutId` becomes dangling; UI falls back to
///   `workoutNameSnapshot`.
/// - `programId` similarly references the containing Program at start time
///   (D-047). Snapshotted names preserve history when the Program or Workout
///   is renamed / deleted.
/// - `healthKitWorkoutUUID` is set when the HKWorkout is written on End
///   Workout (D-028), enabling deletion sync to HealthKit.
@Model
final class Session {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?

    var workoutId: UUID?
    var workoutNameSnapshot: String?
    var programId: UUID?
    var programNameSnapshot: String?

    var note: String?
    var healthKitWorkoutUUID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []

    init(
        startedAt: Date = Date(),
        workoutId: UUID? = nil,
        workoutNameSnapshot: String? = nil,
        programId: UUID? = nil,
        programNameSnapshot: String? = nil
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.workoutId = workoutId
        self.workoutNameSnapshot = workoutNameSnapshot
        self.programId = programId
        self.programNameSnapshot = programNameSnapshot
        self.exercises = []
    }
}
