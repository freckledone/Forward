import Foundation
import SwiftData

/// A single set performed as part of a SessionExercise.
///
/// Named `WorkSet` to avoid collision with Swift's built-in `Set` type.
///
/// - `weightKg` is canonical kilograms per D-004. On `.bodyweight` exercises,
///   this field represents *added* weight (dip belt, vest); zero means
///   bodyweight only.
/// - `rir` is optional Reps-in-Reserve, 0–5 (D-038). 0 = failure.
/// - `completedAt == nil` marks a set that has not yet been logged.
/// - `skipped` distinguishes "I chose to skip this set" from "I haven't gotten
///   to it yet."
@Model
final class WorkSet {
    var id: UUID = UUID()
    var order: Int = 0
    var weightKg: Double = 0
    var reps: Int = 0
    var rir: Int?
    var completedAt: Date?
    var skipped: Bool = false
    var sessionExercise: SessionExercise?

    init(
        order: Int = 0,
        weightKg: Double = 0,
        reps: Int = 0,
        rir: Int? = nil
    ) {
        self.id = UUID()
        self.order = order
        self.weightKg = weightKg
        self.reps = reps
        self.rir = rir
    }
}
