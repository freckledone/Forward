import Foundation
import SwiftData

/// V2 schema (D-072, D-073).
///
/// Adds `CustomExercise`, plus three optional attributes for timed exercises:
/// `WorkSet.durationSeconds` and `targetDurationSeconds` on both
/// `WorkoutExercise` and `SessionExercise`.
///
/// Every change is **additive and optional**, which is what makes the
/// migration lightweight — and lightweight is not a nicety here: CloudKit
/// refuses anything else, and there is already synced data in the wild.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Program.self,
            Workout.self,
            WorkoutExercise.self,
            Session.self,
            SessionExercise.self,
            WorkSet.self,
            ExerciseUserFlag.self,
            UserPreferences.self,
            CustomExercise.self,
        ]
    }
}

/// Migration path for the store (D-034).
///
/// V1 → V2 is lightweight: new optional attributes and one new model, no
/// renames, no type changes, no data to transform. SwiftData infers it.
enum FurtherMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
