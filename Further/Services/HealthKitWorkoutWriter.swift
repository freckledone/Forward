import Foundation
import HealthKit
import Observation

/// Writes completed sessions to Apple Health as `HKWorkout` samples (D-028).
///
/// Scope is deliberately minimal: activity type, start, end, and source. No
/// calorie estimate — Further has no heart-rate or motion data, so any number
/// it produced would be a guess wearing the costume of a measurement. No
/// per-set samples, and **no reads at all**, which keeps this to a single
/// write-only permission scope.
///
/// Every failure here is non-fatal by design. The session is already saved in
/// SwiftData before this runs; Health is a mirror, never the record of truth.
@MainActor
@Observable
final class HealthKitWorkoutWriter {

    enum WriterError: LocalizedError {
        case unavailable
        case notAuthorized
        case sessionNotFinished
        case emptyDuration
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Health isn't available on this device."
            case .notAuthorized:
                return "Further isn't allowed to add workouts to Apple Health. You can change this in Settings › Health › Data Access & Devices."
            case .sessionNotFinished:
                return "That workout hasn't finished yet."
            case .emptyDuration:
                return "That workout was too short to record."
            case .writeFailed:
                return "Apple Health didn't accept the workout."
            }
        }
    }

    private let store = HKHealthStore()

    /// The only type Further ever touches.
    private var workoutType: HKObjectType { HKObjectType.workoutType() }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// HealthKit reports *share* authorization honestly (unlike read
    /// authorization, which it deliberately obscures for privacy).
    var sharingStatus: HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return store.authorizationStatus(for: workoutType)
    }

    var isAuthorized: Bool { sharingStatus == .sharingAuthorized }

    /// The user said no. Surfaced as a plain Bool so the view layer never has
    /// to import HealthKit just to render a warning.
    var isDenied: Bool { sharingStatus == .sharingDenied }

    /// Nobody has been asked on this device yet.
    var isUndecided: Bool { sharingStatus == .notDetermined }

    // MARK: - Authorization

    /// Presents the system permission sheet if the user hasn't decided yet.
    ///
    /// Returns the resulting status rather than throwing on denial: a user
    /// declining is a normal outcome, not an error condition.
    @discardableResult
    func requestAuthorization() async throws -> HKAuthorizationStatus {
        guard isAvailable else { throw WriterError.unavailable }
        try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
        return sharingStatus
    }

    // MARK: - Write

    /// Writes `session` to Health and returns the new workout's UUID.
    ///
    /// Uses `HKWorkoutBuilder` rather than the `HKWorkout` initializers, which
    /// are deprecated as of iOS 17.
    func write(_ session: Session) async throws -> UUID {
        guard isAvailable else { throw WriterError.unavailable }
        guard isAuthorized else { throw WriterError.notAuthorized }
        guard let end = session.endedAt else { throw WriterError.sessionNotFinished }
        guard end > session.startedAt else { throw WriterError.emptyDuration }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(
            healthStore: store,
            configuration: configuration,
            device: .local()
        )

        try await builder.beginCollection(at: session.startedAt)
        try await builder.endCollection(at: end)

        guard let workout = try await builder.finishWorkout() else {
            throw WriterError.writeFailed
        }
        return workout.uuid
    }

    // MARK: - Delete

    /// Removes a previously written workout, so deleting a session in Further
    /// doesn't leave an orphan in Health.
    ///
    /// Silently succeeds when the sample is already gone — the user may have
    /// deleted it from Health directly, and that isn't an error worth
    /// reporting back into a delete flow.
    func deleteWorkout(uuid: UUID) async throws {
        guard isAvailable, isAuthorized else { return }
        guard let workout = try await fetchWorkout(uuid: uuid) else { return }
        try await store.delete(workout)
    }

    private func fetchWorkout(uuid: UUID) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: HKQuery.predicateForObject(with: uuid),
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first as? HKWorkout)
                }
            }
            store.execute(query)
        }
    }
}
