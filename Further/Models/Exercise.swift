import Foundation

/// Read-only value type loaded from the bundled `exercises.json` (D-031).
///
/// This is NOT a SwiftData model. Bundled content stays in-memory as an
/// immutable dictionary; per-user overlays (e.g. `isKey`) live on
/// `ExerciseUserFlag`. Templates and Sessions reference exercises by `id`
/// (stable string slug), not by SwiftData relationship.
///
/// Field semantics: see `docs/06-exercise-database-specification.md`.
struct Exercise: Codable, Identifiable, Hashable {
    let id: String                           // stable kebab-case slug
    let name: String
    let aliases: [String]                    // lowercase; boost search matches
    let loadingMode: LoadingMode
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: [Equipment]
    let movementPattern: MovementPattern?
    let instructions: String?
}
