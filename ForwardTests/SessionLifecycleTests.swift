import Testing
import SwiftData
import Foundation
@testable import Forward

/// `SessionLifecycle` is the only code that creates and rewrites logged
/// training data, and `swapExercise` destroys set state by design. It had no
/// coverage at all until these.
@MainActor
@Suite("SessionLifecycle")
struct SessionLifecycleTests {

    // MARK: - Fixtures

    static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    /// Returns a fixed suggestion for every slot, so seeding is observable
    /// without depending on real history.
    struct StubEngine: SuggestionEngine {
        var suggestion: SuggestedSet?
        func suggest(for exerciseId: String, setIndex: Int, history: [SessionExercise]) -> SuggestedSet? {
            suggestion
        }
    }

    /// An engine that answers only for one exercise id — proves a swap
    /// re-seeds from the *new* exercise rather than carrying the old one over.
    struct PerExerciseEngine: SuggestionEngine {
        var answers: [String: SuggestedSet]
        func suggest(for exerciseId: String, setIndex: Int, history: [SessionExercise]) -> SuggestedSet? {
            answers[exerciseId]
        }
    }

    @discardableResult
    static func makeWorkout(
        in context: ModelContext,
        name: String = "Push",
        exercises: [(id: String, sets: Int, minReps: Int, maxReps: Int)]
    ) -> Workout {
        let program = Program(name: "PPL", displayOrder: 0)
        context.insert(program)

        let workout = Workout(name: name, displayOrder: 0)
        workout.program = program
        context.insert(workout)

        for (i, spec) in exercises.enumerated() {
            let we = WorkoutExercise(
                exerciseId: spec.id,
                displayOrder: i,
                targetSets: spec.sets,
                targetRepsMin: spec.minReps,
                targetRepsMax: spec.maxReps
            )
            we.workout = workout
            context.insert(we)
        }
        return workout
    }

    static func exercise(_ id: String, _ name: String) -> Exercise {
        Exercise(
            id: id, name: name, aliases: [], loadingMode: .weighted,
            primaryMuscles: [.chest], secondaryMuscles: [], equipment: [.barbell],
            movementPattern: nil, instructions: nil
        )
    }

    // MARK: - Start

    @Test("Starting snapshots the workout and program names")
    func startSnapshotsNames() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 3, 6, 8)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )

        #expect(session.workoutNameSnapshot == "Push")
        #expect(session.programNameSnapshot == "PPL")
        #expect(session.workoutId == workout.id)
        #expect(session.programId == workout.program?.id)
        #expect(session.endedAt == nil)
    }

    @Test("Every workout exercise becomes a session exercise, in order")
    func startCopiesExercisesInOrder() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [
            ("bench", 3, 6, 8), ("ohp", 3, 8, 10), ("dips", 2, 10, 12),
        ])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )

        let ordered = (session.exercises ?? []).sorted { $0.displayOrder < $1.displayOrder }
        #expect(ordered.map(\.exerciseId) == ["bench", "ohp", "dips"])
    }

    @Test("Targets are snapshotted, so editing the workout mid-session can't move them")
    func startSnapshotsTargets() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 4, 6, 8)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        let se = try #require(session.exercises?.first)

        // Move the source targets afterwards.
        workout.exercises?.first?.targetSets = 99
        workout.exercises?.first?.targetRepsMin = 1

        #expect(se.targetSets == 4)
        #expect(se.targetRepsMin == 6)
        #expect(se.targetRepsMax == 8)
    }

    @Test("Set count matches the target, and sets are ordered from zero")
    func startCreatesTargetSets() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 4, 6, 8)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        let sets = try #require(session.exercises?.first?.sets).sorted { $0.order < $1.order }

        #expect(sets.count == 4)
        #expect(sets.map(\.order) == [0, 1, 2, 3])
        #expect(sets.allSatisfy { $0.completedAt == nil && !$0.skipped })
    }

    @Test("A zero-set target still yields one set, so the exercise isn't unloggable")
    func startAlwaysCreatesAtLeastOneSet() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 0, 6, 8)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        #expect((session.exercises?.first?.sets ?? []).count == 1)
    }

    @Test("With no suggestion, sets open at zero weight and the target's minimum reps")
    func startFallsBackWithoutSuggestion() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 7, 9)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        let sets = try #require(session.exercises?.first?.sets)

        #expect(sets.allSatisfy { $0.weightKg == 0 })
        #expect(sets.allSatisfy { $0.reps == 7 })
    }

    @Test("A suggestion pre-fills weight and reps")
    func startUsesSuggestion() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 6, 8)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: SuggestedSet(weightKg: 92.5, reps: 8)),
            context: context
        )
        let sets = try #require(session.exercises?.first?.sets)

        #expect(sets.allSatisfy { $0.weightKg == 92.5 })
        #expect(sets.allSatisfy { $0.reps == 8 })
        // Pre-filled is not the same as logged.
        #expect(sets.allSatisfy { $0.completedAt == nil })
    }

    @Test("An unknown slug falls back to itself as the display name")
    func startFallsBackToSlugForUnknownExercise() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("not-in-catalog", 1, 5, 5)])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        #expect(session.exercises?.first?.exerciseNameSnapshot == "not-in-catalog")
    }

    // MARK: - Swap

    @Test("Swapping repoints the exercise but keeps the slot")
    func swapKeepsSlot() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 3, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        let se = try #require(session.exercises?.first)

        SessionLifecycle.swapExercise(
            se, to: Self.exercise("machine-press", "Machine Press"),
            engine: StubEngine(suggestion: nil), context: context
        )

        #expect(se.exerciseId == "machine-press")
        #expect(se.exerciseNameSnapshot == "Machine Press")
        #expect(se.displayOrder == 0)
        #expect(se.targetSets == 3)
        #expect(se.targetRepsMin == 6)
        #expect(se.targetRepsMax == 8)
        #expect((se.sets ?? []).count == 3)
    }

    @Test("Swapping clears logged state — old weights would be wrong on a new movement")
    func swapResetsLoggedSets() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 3, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        let se = try #require(session.exercises?.first)

        for set in se.sets ?? [] {
            set.weightKg = 100
            set.reps = 8
            set.rir = 2
            set.completedAt = Date()
        }
        se.sets?.first?.skipped = true

        SessionLifecycle.swapExercise(
            se, to: Self.exercise("machine-press", "Machine Press"),
            engine: StubEngine(suggestion: nil), context: context
        )

        let sets = try #require(se.sets)
        #expect(sets.allSatisfy { $0.weightKg == 0 })
        #expect(sets.allSatisfy { $0.reps == 6 })       // back to target minimum
        #expect(sets.allSatisfy { $0.rir == nil })
        #expect(sets.allSatisfy { $0.completedAt == nil })
        #expect(sets.allSatisfy { !$0.skipped })
    }

    @Test("A swap re-seeds from the new exercise's history, not the old one's")
    func swapReseedsFromNewExercise() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 6, 8)])
        let engine = PerExerciseEngine(answers: [
            "bench": SuggestedSet(weightKg: 100, reps: 8),
            "machine-press": SuggestedSet(weightKg: 60, reps: 12),
        ])

        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(), engine: engine, context: context
        )
        let se = try #require(session.exercises?.first)
        #expect((se.sets ?? []).allSatisfy { $0.weightKg == 100 })

        SessionLifecycle.swapExercise(
            se, to: Self.exercise("machine-press", "Machine Press"),
            engine: engine, context: context
        )

        let sets = try #require(se.sets)
        #expect(sets.allSatisfy { $0.weightKg == 60 })
        #expect(sets.allSatisfy { $0.reps == 12 })
    }

    @Test("Swapping to the same exercise is a no-op and keeps logged sets")
    func swapToSameExerciseDoesNothing() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        let se = try #require(session.exercises?.first)

        for set in se.sets ?? [] {
            set.weightKg = 100
            set.completedAt = Date()
        }

        SessionLifecycle.swapExercise(
            se, to: Self.exercise("bench", "Bench Press"),
            engine: StubEngine(suggestion: nil), context: context
        )

        #expect((se.sets ?? []).allSatisfy { $0.weightKg == 100 })
        #expect((se.sets ?? []).allSatisfy { $0.completedAt != nil })
    }

    // MARK: - End and discard

    @Test("Ending stamps endedAt and leaves the data alone")
    func endMarksFinished() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )

        #expect(session.endedAt == nil)
        SessionLifecycle.end(session)

        let ended = try #require(session.endedAt)
        #expect(ended >= session.startedAt)
        #expect((session.exercises ?? []).count == 1)
    }

    @Test("Discarding removes the session and cascades to its sets")
    func discardCascades() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 3, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        try context.save()
        #expect(try context.fetch(FetchDescriptor<WorkSet>()).count == 3)

        SessionLifecycle.discard(session, context: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SessionExercise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WorkSet>()).isEmpty)
    }

    @Test("Deleting a workout leaves its logged sessions intact")
    func deletingWorkoutKeepsHistory() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        SessionLifecycle.end(session)
        try context.save()

        context.delete(workout)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.workoutNameSnapshot == "Push")
    }

    // MARK: - History

    @Test("History excludes the session being built, so it can't seed from itself")
    func historyExcludesCurrentSession() throws {
        let context = try Self.makeContext()
        let workout = Self.makeWorkout(in: context, exercises: [("bench", 2, 6, 8)])
        let session = SessionLifecycle.start(
            from: workout, catalog: ExerciseCatalog(),
            engine: StubEngine(suggestion: nil), context: context
        )
        try context.save()

        let history = SessionLifecycle.fetchHistory(
            for: "bench", excluding: session.id, in: context
        )
        #expect(history.isEmpty)

        let all = SessionLifecycle.fetchHistory(for: "bench", excluding: UUID(), in: context)
        #expect(all.count == 1)
    }
}
