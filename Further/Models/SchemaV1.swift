import Foundation
import SwiftData

/// V1 schema container per D-034.
///
/// Every V2+ change adds a new versioned schema plus a `SchemaMigrationPlan`
/// step. Starting with `VersionedSchema` from day one avoids painful
/// retroactive migration when users already have iCloud-synced data.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

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
        ]
    }
}
