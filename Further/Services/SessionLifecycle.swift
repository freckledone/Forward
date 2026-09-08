import Foundation
import SwiftData

/// Materialize and finalize `Session` records.
///
/// Per D-029 §5.1, starting a session:
///   1. Creates a `Session` with `startedAt = now`, snapshotting the source
///      Workout and Program names (D-047).
///   2. For each `WorkoutExercise`, creates a `SessionExercise` (with the
///      exercise's current display-name snapshot).
///   3. For each expected set, creates a `WorkSet` pre-filled by the
///      `SuggestionEngine` from history (D-007). No suggestion = zero weight
///      + target-min reps.
///   4. Persists via the given `ModelContext`.
///
/// Ending a session (D-029 §5.3) marks `endedAt = now`. HealthKit write is
/// intentionally NOT called here; the caller (End Workout summary) handles it
/// so the write happens exactly once, and only if HealthKit is enabled.
enum SessionLifecycle {

    // MARK: - Start

    static func start(
        from workout: Workout,
        catalog: ExerciseCatalog,
        engine: SuggestionEngine,
        context: ModelContext
    ) -> Session {
        let session = Session(
            startedAt: Date(),
            workoutId: workout.id,
            workoutNameSnapshot: workout.name,
            programId: workout.program?.id,
            programNameSnapshot: workout.program?.name
        )
        context.insert(session)

        let orderedExercises =
            (workout.exercises ?? []).sorted { $0.displayOrder < $1.displayOrder }

        for we in orderedExercises {
            let name = catalog.exercise(withId: we.exerciseId)?.name ?? we.exerciseId
            let se = SessionExercise(
                exerciseId: we.exerciseId,
                exerciseNameSnapshot: name,
                displayOrder: we.displayOrder,
                targetSets: we.targetSets,
                targetRepsMin: we.targetRepsMin,
                targetRepsMax: we.targetRepsMax
            )
            se.session = session
            context.insert(se)

            let history = fetchHistory(for: we.exerciseId, excluding: session.id, in: context)

            for setIndex in 0..<max(we.targetSets, 1) {
                let suggestion = engine.suggest(
                    for: we.exerciseId,
                    setIndex: setIndex,
                    history: history
                )
                let set = WorkSet(
                    order: setIndex,
                    weightKg: suggestion?.weightKg ?? 0,
                    reps: suggestion?.reps ?? we.targetRepsMin,
                    rir: nil
                )
                set.sessionExercise = se
                context.insert(set)
            }
        }

        return session
    }

    // MARK: - Swap (mid-session)

    /// Replace the exercise a `SessionExercise` points at, keeping its slot,
    /// set count and target rep range.
    ///
    /// Used when the planned machine is occupied or the user simply doesn't
    /// feel like the movement. Every set is re-seeded from the *new* exercise's
    /// history via the `SuggestionEngine` and reset to "not logged yet" —
    /// weights from the old movement would be meaningless (and dangerous) on
    /// the new one.
    static func swapExercise(
        _ sessionExercise: SessionExercise,
        to exercise: Exercise,
        engine: SuggestionEngine,
        context: ModelContext
    ) {
        guard sessionExercise.exerciseId != exercise.id else { return }

        sessionExercise.exerciseId = exercise.id
        sessionExercise.exerciseNameSnapshot = exercise.name

        let history = fetchHistory(
            for: exercise.id,
            excluding: sessionExercise.session?.id ?? UUID(),
            in: context
        )

        let sets = (sessionExercise.sets ?? []).sorted { $0.order < $1.order }
        for (index, set) in sets.enumerated() {
            let suggestion = engine.suggest(
                for: exercise.id,
                setIndex: index,
                history: history
            )
            set.weightKg = suggestion?.weightKg ?? 0
            set.reps = suggestion?.reps ?? sessionExercise.targetRepsMin
            set.rir = nil
            set.completedAt = nil
            set.skipped = false
        }
    }

    // MARK: - End

    static func end(_ session: Session) {
        session.endedAt = Date()
    }

    // MARK: - Discard (in-progress)

    static func discard(_ session: Session, context: ModelContext) {
        context.delete(session)
    }

    // MARK: - History fetch

    /// Past `SessionExercise` records for `exerciseId`, most-recent-first,
    /// excluding the session currently being built.
    static func fetchHistory(
        for exerciseId: String,
        excluding sessionId: UUID,
        in context: ModelContext
    ) -> [SessionExercise] {
        var descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { $0.exerciseId == exerciseId },
            sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        do {
            let all = try context.fetch(descriptor)
            return all.filter { $0.session?.id != sessionId }
        } catch {
            return []
        }
    }
}
