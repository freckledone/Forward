import Foundation
import SwiftData

/// JSON backup and restore for everything the user owns.
///
/// The bundled exercise catalog is deliberately **not** in the archive — it
/// ships with the app and is read-only (D-031). Records reference exercises by
/// their stable string slug, so an archive stays valid across catalog updates.
///
/// Import is **additive and keyed by UUID**: records whose id already exists
/// are skipped, never overwritten. Restoring onto an empty store is a full
/// restore; restoring onto a populated store adds only what's missing; running
/// the same file twice changes nothing the second time. There is no "replace
/// all" — a backup tool that can destroy the thing it exists to protect is the
/// wrong shape.
enum DataArchive {

    /// Bumped only for breaking format changes. A reader must refuse a file
    /// from the future rather than silently drop fields it doesn't know.
    static let currentFormatVersion = 1

    // MARK: - Document shape

    struct Document: Codable {
        var formatVersion: Int
        var exportedAt: Date
        var appVersion: String?
        var preferences: Preferences?
        var programs: [Program]
        /// Workouts whose `program` relationship is nil. Shouldn't normally
        /// happen — every code path assigns one — but the relationship is
        /// optional for CloudKit (D-030), and a backup that silently drops
        /// data is worse than no backup.
        var unassignedWorkouts: [Workout]
        var sessions: [Session]
        var exerciseFlags: [ExerciseFlag]

        struct Preferences: Codable {
            var displayUnitRaw: String
            var healthKitEnabled: Bool
        }

        struct Program: Codable {
            var id: UUID
            var name: String
            var displayOrder: Int
            var createdAt: Date
            var updatedAt: Date
            var workouts: [Workout]
        }

        struct Workout: Codable {
            var id: UUID
            var name: String
            var displayOrder: Int
            var createdAt: Date
            var updatedAt: Date
            var tintOverrideRaw: String?
            var exercises: [WorkoutExercise]
        }

        struct WorkoutExercise: Codable {
            var id: UUID
            var exerciseId: String
            var displayOrder: Int
            var targetSets: Int
            var targetRepsMin: Int
            var targetRepsMax: Int
        }

        struct Session: Codable {
            var id: UUID
            var startedAt: Date
            var endedAt: Date?
            var workoutId: UUID?
            var workoutNameSnapshot: String?
            var programId: UUID?
            var programNameSnapshot: String?
            var note: String?
            var healthKitWorkoutUUID: UUID?
            var exercises: [SessionExercise]
        }

        struct SessionExercise: Codable {
            var id: UUID
            var exerciseId: String
            var exerciseNameSnapshot: String
            var displayOrder: Int
            var targetSets: Int
            var targetRepsMin: Int
            var targetRepsMax: Int
            var sets: [WorkSet]
        }

        struct WorkSet: Codable {
            var id: UUID
            var order: Int
            var weightKg: Double
            var reps: Int
            var rir: Int?
            var completedAt: Date?
            var skipped: Bool
        }

        struct ExerciseFlag: Codable {
            var id: UUID
            var exerciseId: String
            var isKey: Bool
            var updatedAt: Date
        }
    }

    // MARK: - Coders

    /// ISO-8601 dates and sorted keys so two exports of unchanged data are
    /// byte-identical and diffable.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Errors

    enum ArchiveError: LocalizedError {
        case unreadableFile
        case malformedJSON(String)
        case futureFormat(Int)

        var errorDescription: String? {
            switch self {
            case .unreadableFile:
                return "That file couldn't be opened."
            case .malformedJSON(let detail):
                return "That file isn't a valid Further backup. (\(detail))"
            case .futureFormat(let version):
                return "This backup was made by a newer version of Further (format \(version)). Update the app, then try again."
            }
        }
    }

    // MARK: - Export

    static func export(from context: ModelContext) throws -> Data {
        let programs = try context.fetch(
            FetchDescriptor<Further.Program>(sortBy: [SortDescriptor(\.displayOrder)])
        )
        let allWorkouts = try context.fetch(FetchDescriptor<Further.Workout>())
        let sessions = try context.fetch(
            FetchDescriptor<Further.Session>(sortBy: [SortDescriptor(\.startedAt)])
        )
        let flags = try context.fetch(FetchDescriptor<Further.ExerciseUserFlag>())
        let prefs = try context.fetch(FetchDescriptor<Further.UserPreferences>()).first

        let document = Document(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            preferences: prefs.map {
                Document.Preferences(
                    displayUnitRaw: $0.displayUnitRaw,
                    healthKitEnabled: $0.healthKitEnabled
                )
            },
            programs: programs.map(encodeProgram),
            unassignedWorkouts: allWorkouts
                .filter { $0.program == nil }
                .sorted { $0.displayOrder < $1.displayOrder }
                .map(encodeWorkout),
            sessions: sessions.map(encodeSession),
            exerciseFlags: flags.map {
                Document.ExerciseFlag(
                    id: $0.id,
                    exerciseId: $0.exerciseId,
                    isKey: $0.isKey,
                    updatedAt: $0.updatedAt
                )
            }
        )

        return try makeEncoder().encode(document)
    }

    private static func encodeProgram(_ program: Further.Program) -> Document.Program {
        Document.Program(
            id: program.id,
            name: program.name,
            displayOrder: program.displayOrder,
            createdAt: program.createdAt,
            updatedAt: program.updatedAt,
            workouts: (program.workouts ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map(encodeWorkout)
        )
    }

    private static func encodeWorkout(_ workout: Further.Workout) -> Document.Workout {
        Document.Workout(
            id: workout.id,
            name: workout.name,
            displayOrder: workout.displayOrder,
            createdAt: workout.createdAt,
            updatedAt: workout.updatedAt,
            tintOverrideRaw: workout.tintOverrideRaw,
            exercises: (workout.exercises ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map { we in
                    Document.WorkoutExercise(
                        id: we.id,
                        exerciseId: we.exerciseId,
                        displayOrder: we.displayOrder,
                        targetSets: we.targetSets,
                        targetRepsMin: we.targetRepsMin,
                        targetRepsMax: we.targetRepsMax
                    )
                }
        )
    }

    private static func encodeSession(_ session: Further.Session) -> Document.Session {
        Document.Session(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            workoutId: session.workoutId,
            workoutNameSnapshot: session.workoutNameSnapshot,
            programId: session.programId,
            programNameSnapshot: session.programNameSnapshot,
            note: session.note,
            healthKitWorkoutUUID: session.healthKitWorkoutUUID,
            exercises: (session.exercises ?? [])
                .sorted { $0.displayOrder < $1.displayOrder }
                .map { se in
                    Document.SessionExercise(
                        id: se.id,
                        exerciseId: se.exerciseId,
                        exerciseNameSnapshot: se.exerciseNameSnapshot,
                        displayOrder: se.displayOrder,
                        targetSets: se.targetSets,
                        targetRepsMin: se.targetRepsMin,
                        targetRepsMax: se.targetRepsMax,
                        sets: (se.sets ?? [])
                            .sorted { $0.order < $1.order }
                            .map { s in
                                Document.WorkSet(
                                    id: s.id,
                                    order: s.order,
                                    weightKg: s.weightKg,
                                    reps: s.reps,
                                    rir: s.rir,
                                    completedAt: s.completedAt,
                                    skipped: s.skipped
                                )
                            }
                    )
                }
        )
    }

    // MARK: - Import

    struct ImportSummary: Equatable {
        var programs = 0
        var workouts = 0
        var sessions = 0
        var exerciseFlags = 0
        var skipped = 0
        var preferencesApplied = false

        var addedAnything: Bool {
            programs + workouts + sessions + exerciseFlags > 0 || preferencesApplied
        }

        /// "2 programs, 6 workouts, 41 sessions" — omits zero counts so the
        /// alert reads as a sentence rather than a form.
        var description: String {
            var parts: [String] = []
            if programs > 0 { parts.append(programs == 1 ? "1 program" : "\(programs) programs") }
            if workouts > 0 { parts.append(workouts == 1 ? "1 workout" : "\(workouts) workouts") }
            if sessions > 0 { parts.append(sessions == 1 ? "1 session" : "\(sessions) sessions") }
            if exerciseFlags > 0 {
                parts.append(exerciseFlags == 1 ? "1 starred exercise" : "\(exerciseFlags) starred exercises")
            }
            if parts.isEmpty { return "Nothing new to add." }
            return "Added " + parts.joined(separator: ", ") + "."
        }
    }

    static func decode(_ data: Data) throws -> Document {
        let document: Document
        do {
            document = try makeDecoder().decode(Document.self, from: data)
        } catch let error as DecodingError {
            throw ArchiveError.malformedJSON(shortDescription(of: error))
        } catch {
            throw ArchiveError.malformedJSON(error.localizedDescription)
        }

        guard document.formatVersion <= currentFormatVersion else {
            throw ArchiveError.futureFormat(document.formatVersion)
        }
        return document
    }

    @discardableResult
    static func importArchive(_ document: Document, into context: ModelContext) throws -> ImportSummary {
        var summary = ImportSummary()

        // Existing ids, gathered once — an id already present always wins.
        var knownPrograms = Set(try context.fetch(FetchDescriptor<Further.Program>()).map(\.id))
        var knownWorkouts = Set(try context.fetch(FetchDescriptor<Further.Workout>()).map(\.id))
        let knownSessions = Set(try context.fetch(FetchDescriptor<Further.Session>()).map(\.id))
        let knownFlags = Set(try context.fetch(FetchDescriptor<Further.ExerciseUserFlag>()).map(\.exerciseId))

        for archived in document.programs {
            guard !knownPrograms.contains(archived.id) else {
                summary.skipped += 1
                for workout in archived.workouts where !knownWorkouts.contains(workout.id) {
                    // The program survived but one of its workouts was
                    // deleted since — put it back where it belongs.
                    if let target = try findProgram(id: archived.id, in: context) {
                        insert(workout, into: target, context: context)
                        knownWorkouts.insert(workout.id)
                        summary.workouts += 1
                    }
                }
                continue
            }

            let program = Further.Program(name: archived.name, displayOrder: archived.displayOrder)
            program.id = archived.id
            program.createdAt = archived.createdAt
            program.updatedAt = archived.updatedAt
            context.insert(program)
            knownPrograms.insert(archived.id)
            summary.programs += 1

            for workout in archived.workouts where !knownWorkouts.contains(workout.id) {
                insert(workout, into: program, context: context)
                knownWorkouts.insert(workout.id)
                summary.workouts += 1
            }
        }

        for archived in document.unassignedWorkouts where !knownWorkouts.contains(archived.id) {
            insert(archived, into: nil, context: context)
            knownWorkouts.insert(archived.id)
            summary.workouts += 1
        }

        for archived in document.sessions {
            guard !knownSessions.contains(archived.id) else {
                summary.skipped += 1
                continue
            }
            insert(archived, context: context)
            summary.sessions += 1
        }

        for archived in document.exerciseFlags {
            guard !knownFlags.contains(archived.exerciseId) else {
                summary.skipped += 1
                continue
            }
            let flag = Further.ExerciseUserFlag(exerciseId: archived.exerciseId, isKey: archived.isKey)
            flag.id = archived.id
            flag.updatedAt = archived.updatedAt
            context.insert(flag)
            summary.exerciseFlags += 1
        }

        // Preferences are applied only on a store that has none — i.e. a
        // fresh install being restored. Merging into a configured app must
        // not silently flip the user's unit setting out from under them.
        if let archivedPrefs = document.preferences,
           try context.fetch(FetchDescriptor<Further.UserPreferences>()).isEmpty {
            let prefs = Further.UserPreferences()
            prefs.displayUnitRaw = archivedPrefs.displayUnitRaw
            prefs.healthKitEnabled = archivedPrefs.healthKitEnabled
            context.insert(prefs)
            summary.preferencesApplied = true
        }

        return summary
    }

    // MARK: - Insert helpers

    private static func findProgram(id: UUID, in context: ModelContext) throws -> Further.Program? {
        var descriptor = FetchDescriptor<Further.Program>(
            predicate: #Predicate<Further.Program> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func insert(
        _ archived: Document.Workout,
        into program: Further.Program?,
        context: ModelContext
    ) {
        let workout = Further.Workout(name: archived.name, displayOrder: archived.displayOrder)
        workout.id = archived.id
        workout.createdAt = archived.createdAt
        workout.updatedAt = archived.updatedAt
        workout.tintOverrideRaw = archived.tintOverrideRaw
        workout.program = program
        context.insert(workout)

        for archivedExercise in archived.exercises {
            let we = Further.WorkoutExercise(
                exerciseId: archivedExercise.exerciseId,
                displayOrder: archivedExercise.displayOrder,
                targetSets: archivedExercise.targetSets,
                targetRepsMin: archivedExercise.targetRepsMin,
                targetRepsMax: archivedExercise.targetRepsMax
            )
            we.id = archivedExercise.id
            we.workout = workout
            context.insert(we)
        }
    }

    private static func insert(_ archived: Document.Session, context: ModelContext) {
        let session = Further.Session(
            startedAt: archived.startedAt,
            workoutId: archived.workoutId,
            workoutNameSnapshot: archived.workoutNameSnapshot,
            programId: archived.programId,
            programNameSnapshot: archived.programNameSnapshot
        )
        session.id = archived.id
        session.endedAt = archived.endedAt
        session.note = archived.note
        session.healthKitWorkoutUUID = archived.healthKitWorkoutUUID
        context.insert(session)

        for archivedExercise in archived.exercises {
            let se = Further.SessionExercise(
                exerciseId: archivedExercise.exerciseId,
                exerciseNameSnapshot: archivedExercise.exerciseNameSnapshot,
                displayOrder: archivedExercise.displayOrder,
                targetSets: archivedExercise.targetSets,
                targetRepsMin: archivedExercise.targetRepsMin,
                targetRepsMax: archivedExercise.targetRepsMax
            )
            se.id = archivedExercise.id
            se.session = session
            context.insert(se)

            for archivedSet in archivedExercise.sets {
                let set = Further.WorkSet(
                    order: archivedSet.order,
                    weightKg: archivedSet.weightKg,
                    reps: archivedSet.reps,
                    rir: archivedSet.rir
                )
                set.id = archivedSet.id
                set.completedAt = archivedSet.completedAt
                set.skipped = archivedSet.skipped
                set.sessionExercise = se
                context.insert(set)
            }
        }
    }

    // MARK: - Diagnostics

    private static func shortDescription(of error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "missing field \"\(key.stringValue)\""
        case .typeMismatch(_, let ctx), .valueNotFound(_, let ctx):
            let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? "unexpected structure" : "bad value at \(path)"
        case .dataCorrupted:
            return "not JSON"
        @unknown default:
            return "unreadable"
        }
    }
}
