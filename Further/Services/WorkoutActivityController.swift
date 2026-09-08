import ActivityKit
import Foundation
import Observation

/// Starts, updates and ends the workout Live Activity (D-074).
///
/// Every failure here is silent and non-fatal. The Live Activity is a mirror of
/// a session that is already saved in SwiftData; if the user has them disabled,
/// the system is out of slots, or an update is throttled, the workout must
/// carry on regardless. Nothing in this file is allowed to fail a set.
@MainActor
@Observable
final class WorkoutActivityController {

    private var activity: Activity<WorkoutActivityAttributes>?

    /// False when Live Activities are switched off for the app in Settings.
    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Lifecycle

    func start(workoutName: String, startedAt: Date, state: WorkoutActivityAttributes.ContentState) {
        guard isAvailable, activity == nil else { return }

        let attributes = WorkoutActivityAttributes(
            workoutName: workoutName,
            startedAt: startedAt
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Ends immediately rather than lingering on the Lock Screen. The session
    /// is over; a stale card claiming otherwise is worse than none.
    func end() {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Clears anything left over from a previous launch — a crash mid-workout
    /// would otherwise strand a card that no longer has a session behind it.
    func endOrphanedActivities() {
        Task {
            for stale in Activity<WorkoutActivityAttributes>.activities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
