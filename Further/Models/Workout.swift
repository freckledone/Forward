import Foundation
import SwiftData

/// A saved workout — the reusable "workout day" the user runs (D-047, D-005).
///
/// Formerly `Template`. Renamed per D-047 to match training vocabulary.
/// Belongs to a `Program`. Defines *structure* — exercises, set counts,
/// target rep ranges — but not prescribed weights. Weights are produced by
/// `SuggestionEngine` from history (D-007).
///
/// Deleting a Workout does NOT cascade to `Session` records. Sessions keep
/// `workoutId` as a weak reference plus `workoutNameSnapshot` for history.
///
/// CloudKit constraints (D-030): optional / defaulted properties, no unique
/// attributes, explicit inverse relationships.
@Model
final class Workout {
    var id: UUID = UUID()
    var name: String = ""
    var displayOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Optional explicit tint override (`MuscleGroup.rawValue`). When nil,
    /// the card tint auto-derives from the first exercise's primary muscle.
    /// String storage keeps the schema CloudKit-safe.
    var tintOverrideRaw: String?

    var program: Program?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]? = []

    init(name: String = "", displayOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.exercises = []
    }

    /// User-chosen tint. `nil` means "auto" (derive from first exercise).
    var tintOverride: MuscleGroup? {
        get { tintOverrideRaw.flatMap(MuscleGroup.init(rawValue:)) }
        set { tintOverrideRaw = newValue?.rawValue }
    }
}
