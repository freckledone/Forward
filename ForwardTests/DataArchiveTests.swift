import Testing
import SwiftData
import Foundation
@testable import Forward

@MainActor
@Suite("DataArchive")
struct DataArchiveTests {

    // MARK: - Fixture

    static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// A program with one workout (two exercise slots) and one completed
    /// session logging two sets, plus a starred exercise and preferences.
    @discardableResult
    static func populate(_ context: ModelContext) -> (program: Program, session: Session) {
        let program = Program(name: "PPL", displayOrder: 0)
        context.insert(program)

        let workout = Workout(name: "Push", displayOrder: 0)
        workout.tintOverride = .chest
        workout.program = program
        context.insert(workout)

        for (i, slug) in ["bench-press", "overhead-press"].enumerated() {
            let we = WorkoutExercise(
                exerciseId: slug,
                displayOrder: i,
                targetSets: 3,
                targetRepsMin: 6,
                targetRepsMax: 8
            )
            we.workout = workout
            context.insert(we)
        }

        let session = Session(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            workoutId: workout.id,
            workoutNameSnapshot: "Push",
            programId: program.id,
            programNameSnapshot: "PPL"
        )
        session.endedAt = Date(timeIntervalSince1970: 1_700_003_600)
        session.note = "Felt strong"
        context.insert(session)

        let se = SessionExercise(
            exerciseId: "bench-press",
            exerciseNameSnapshot: "Bench Press",
            displayOrder: 0,
            targetSets: 3,
            targetRepsMin: 6,
            targetRepsMax: 8
        )
        se.session = session
        context.insert(se)

        for i in 0..<2 {
            let set = WorkSet(order: i, weightKg: 100 + Double(i) * 2.5, reps: 8, rir: 2)
            set.completedAt = Date(timeIntervalSince1970: 1_700_001_000)
            set.sessionExercise = se
            context.insert(set)
        }

        let flag = ExerciseUserFlag(exerciseId: "bench-press", isKey: true)
        context.insert(flag)

        let prefs = UserPreferences()
        prefs.unit = .lb
        context.insert(prefs)

        return (program, session)
    }

    static func roundTrip(_ source: ModelContext, into destination: ModelContext) throws -> DataArchive.ImportSummary {
        let data = try DataArchive.export(from: source)
        let document = try DataArchive.decode(data)
        return try DataArchive.importArchive(document, into: destination)
    }

    // MARK: - Export

    @Test("Export of an empty store is valid and empty")
    func exportEmpty() throws {
        let context = try Self.makeContext()
        let document = try DataArchive.decode(DataArchive.export(from: context))

        #expect(document.formatVersion == DataArchive.currentFormatVersion)
        #expect(document.programs.isEmpty)
        #expect(document.sessions.isEmpty)
        #expect(document.exerciseFlags.isEmpty)
        #expect(document.preferences == nil)
    }

    @Test("Export captures the full object graph")
    func exportGraph() throws {
        let context = try Self.makeContext()
        Self.populate(context)

        let document = try DataArchive.decode(DataArchive.export(from: context))

        #expect(document.programs.count == 1)
        #expect(document.programs[0].name == "PPL")
        #expect(document.programs[0].workouts.count == 1)
        #expect(document.programs[0].workouts[0].tintOverrideRaw == MuscleGroup.chest.rawValue)
        #expect(document.programs[0].workouts[0].exercises.count == 2)
        #expect(document.sessions.count == 1)
        #expect(document.sessions[0].note == "Felt strong")
        #expect(document.sessions[0].exercises.count == 1)
        #expect(document.sessions[0].exercises[0].sets.count == 2)
        #expect(document.exerciseFlags.count == 1)
        #expect(document.preferences?.displayUnitRaw == DisplayUnit.lb.rawValue)
        #expect(document.unassignedWorkouts.isEmpty)
    }

    @Test("A workout with no program still lands in the archive")
    func exportUnassignedWorkout() throws {
        let context = try Self.makeContext()
        let orphan = Workout(name: "Loose", displayOrder: 0)
        context.insert(orphan)

        let document = try DataArchive.decode(DataArchive.export(from: context))
        #expect(document.programs.isEmpty)
        #expect(document.unassignedWorkouts.count == 1)
        #expect(document.unassignedWorkouts[0].name == "Loose")
    }

    // MARK: - Round trip

    @Test("Restore into an empty store reproduces every record")
    func roundTripRestore() throws {
        let source = try Self.makeContext()
        Self.populate(source)
        let destination = try Self.makeContext()

        let summary = try Self.roundTrip(source, into: destination)
        #expect(summary.programs == 1)
        #expect(summary.workouts == 1)
        #expect(summary.sessions == 1)
        #expect(summary.exerciseFlags == 1)
        #expect(summary.preferencesApplied)

        let programs = try destination.fetch(FetchDescriptor<Program>())
        #expect(programs.count == 1)
        #expect(programs[0].name == "PPL")
        #expect((programs[0].workouts ?? []).count == 1)

        let workouts = try destination.fetch(FetchDescriptor<Workout>())
        #expect(workouts[0].tintOverride == .chest)
        #expect((workouts[0].exercises ?? []).count == 2)
        #expect(workouts[0].program?.id == programs[0].id)

        let sessions = try destination.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(sessions[0].note == "Felt strong")

        let sets = try destination.fetch(FetchDescriptor<WorkSet>())
        #expect(sets.count == 2)
        #expect(sets.contains { $0.weightKg == 102.5 && $0.reps == 8 && $0.rir == 2 })
        #expect(sets.allSatisfy { $0.sessionExercise != nil })

        let prefs = try destination.fetch(FetchDescriptor<UserPreferences>())
        #expect(prefs.first?.unit == .lb)
    }

    @Test("Identity is preserved so a restore is comparable to its source")
    func roundTripPreservesIds() throws {
        let source = try Self.makeContext()
        let (program, session) = Self.populate(source)
        let destination = try Self.makeContext()

        try Self.roundTrip(source, into: destination)

        let restoredPrograms = try destination.fetch(FetchDescriptor<Program>())
        let restoredSessions = try destination.fetch(FetchDescriptor<Session>())
        #expect(restoredPrograms.first?.id == program.id)
        #expect(restoredSessions.first?.id == session.id)
    }

    // MARK: - Merge semantics

    @Test("Importing the same file twice adds nothing the second time")
    func importIsIdempotent() throws {
        let source = try Self.makeContext()
        Self.populate(source)
        let destination = try Self.makeContext()

        let data = try DataArchive.export(from: source)
        let first = try DataArchive.importArchive(try DataArchive.decode(data), into: destination)
        #expect(first.addedAnything)

        let second = try DataArchive.importArchive(try DataArchive.decode(data), into: destination)
        #expect(!second.addedAnything)
        #expect(second.skipped > 0)

        #expect(try destination.fetch(FetchDescriptor<Program>()).count == 1)
        #expect(try destination.fetch(FetchDescriptor<Session>()).count == 1)
        #expect(try destination.fetch(FetchDescriptor<WorkSet>()).count == 2)
    }

    @Test("Import never overwrites an existing record")
    func importDoesNotOverwrite() throws {
        let source = try Self.makeContext()
        Self.populate(source)
        let data = try DataArchive.export(from: source)

        // Same store, but the program has since been renamed.
        let programs = try source.fetch(FetchDescriptor<Program>())
        programs[0].name = "Renamed Locally"

        let summary = try DataArchive.importArchive(try DataArchive.decode(data), into: source)
        #expect(summary.programs == 0)

        let after = try source.fetch(FetchDescriptor<Program>())
        #expect(after.count == 1)
        #expect(after[0].name == "Renamed Locally")
    }

    @Test("Import merges alongside unrelated local data")
    func importMergesWithExisting() throws {
        let source = try Self.makeContext()
        Self.populate(source)

        let destination = try Self.makeContext()
        let local = Program(name: "Local Only", displayOrder: 5)
        context_insert(local, destination)

        let summary = try Self.roundTrip(source, into: destination)
        #expect(summary.programs == 1)

        let programs = try destination.fetch(FetchDescriptor<Program>())
        #expect(programs.count == 2)
        #expect(programs.contains { $0.name == "Local Only" })
        #expect(programs.contains { $0.name == "PPL" })
    }

    @Test("A workout deleted since the backup is restored into its program")
    func importRestoresMissingWorkout() throws {
        let source = try Self.makeContext()
        Self.populate(source)
        let data = try DataArchive.export(from: source)

        let workouts = try source.fetch(FetchDescriptor<Workout>())
        source.delete(workouts[0])

        let summary = try DataArchive.importArchive(try DataArchive.decode(data), into: source)
        #expect(summary.programs == 0)
        #expect(summary.workouts == 1)

        let restored = try source.fetch(FetchDescriptor<Workout>())
        #expect(restored.count == 1)
        #expect(restored[0].program?.name == "PPL")
        #expect((restored[0].exercises ?? []).count == 2)
    }

    @Test("Preferences are left alone when the store already has some")
    func importDoesNotClobberPreferences() throws {
        let source = try Self.makeContext()
        Self.populate(source)  // exports lb

        let destination = try Self.makeContext()
        let localPrefs = UserPreferences()
        localPrefs.unit = .kg
        context_insert(localPrefs, destination)

        let summary = try Self.roundTrip(source, into: destination)
        #expect(!summary.preferencesApplied)

        let prefs = try destination.fetch(FetchDescriptor<UserPreferences>())
        #expect(prefs.count == 1)
        #expect(prefs[0].unit == .kg)
    }

    // MARK: - Bad input

    @Test("Non-JSON input is rejected, not crashed on")
    func rejectsGarbage() throws {
        let data = Data("this is not json".utf8)
        #expect(throws: DataArchive.ArchiveError.self) {
            try DataArchive.decode(data)
        }
    }

    @Test("JSON of the wrong shape is rejected")
    func rejectsWrongShape() throws {
        let data = Data(#"{"hello":"world"}"#.utf8)
        #expect(throws: DataArchive.ArchiveError.self) {
            try DataArchive.decode(data)
        }
    }

    @Test("A backup from a newer app version is refused")
    func rejectsFutureFormat() throws {
        let source = try Self.makeContext()
        var document = try DataArchive.decode(DataArchive.export(from: source))
        document.formatVersion = DataArchive.currentFormatVersion + 1
        let data = try DataArchive.makeEncoder().encode(document)

        #expect(throws: DataArchive.ArchiveError.self) {
            try DataArchive.decode(data)
        }
    }

    // MARK: - Helper

    private func context_insert(_ model: some PersistentModel, _ context: ModelContext) {
        context.insert(model)
    }
}
