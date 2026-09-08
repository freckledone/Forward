import Foundation
import SwiftData

/// Per-user overlay on a bundled Exercise (D-031).
///
/// The bundled exercise catalog is read-only; user-owned state that varies
/// per-exercise lives here and syncs via CloudKit. Currently only `isKey`
/// (Progress-dashboard membership, D-020). Future flags can be added as
/// non-breaking migrations.
///
/// Keyed by `exerciseId` (bundled Exercise slug). One row per exercise per
/// user (soft-enforced — no unique constraint per CloudKit rules).
@Model
final class ExerciseUserFlag {
    var id: UUID = UUID()
    var exerciseId: String = ""
    var isKey: Bool = false
    var updatedAt: Date = Date()

    init(exerciseId: String = "", isKey: Bool = false) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.isKey = isKey
        self.updatedAt = Date()
    }
}
