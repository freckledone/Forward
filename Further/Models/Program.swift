import Foundation
import SwiftData

/// A named grouping of related Workouts (D-047).
///
/// A Program is *organizational only*. It does NOT model periodization
/// (cycles, blocks, deloads) — that remains parking-lot per D-041. Users
/// typically have one active Program at a time (e.g. "PPL", "Summer Cut")
/// containing 3–5 Workouts. New workouts are auto-assigned to a default
/// Program ("My Program"), created lazily on first use.
///
/// CloudKit constraints (D-030): optional / defaulted properties, no unique
/// attributes, explicit inverse relationships.
@Model
final class Program {
    var id: UUID = UUID()
    var name: String = ""
    var displayOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Workout.program)
    var workouts: [Workout]? = []

    init(name: String = "", displayOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.displayOrder = displayOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.workouts = []
    }
}
