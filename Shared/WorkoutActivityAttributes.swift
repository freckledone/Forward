import ActivityKit
import Foundation

/// Shape of the Live Activity, shared by the app (which starts and updates it)
/// and the widget extension (which draws it).
///
/// Lives in `Shared/` because a synchronized folder belongs to exactly one
/// target, and both need this type compiled in. Duplicating it would let the
/// two definitions drift, and a mismatch here fails at runtime rather than at
/// build time.
struct WorkoutActivityAttributes: ActivityAttributes {

    /// Everything that changes while the workout runs.
    ///
    /// Elapsed time is deliberately absent: `startedAt` is fixed for the whole
    /// session, so the views can render a self-updating timer from it. Pushing
    /// a new value every second would burn the system's update budget to say
    /// something the date already implies.
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var completedSets: Int
        var totalSets: Int
        /// 1-based, for "3 of 6".
        var exercisePosition: Int
        var exerciseCount: Int

        var setsLabel: String { "\(completedSets)/\(totalSets)" }
        var exerciseLabel: String { "\(exercisePosition) of \(exerciseCount)" }
    }

    var workoutName: String
    var startedAt: Date
}
