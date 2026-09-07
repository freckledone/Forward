import SwiftUI
import SwiftData

/// The flagship screen (D-012, Design System §6/§7).
///
/// Model C hybrid grid: all exercises visible. The user-selected "current"
/// exercise is expanded with its full set grid; the rest render as collapsed
/// rows. Tap a collapsed row to make it current.
///
/// End Workout in the toolbar dismisses via the parent through
/// `onFinish(session)` — the parent presents the End Workout summary sheet.
struct ActiveWorkoutView: View {
    @Bindable var session: Session
    let onFinish: (Session) -> Void
    let onDiscard: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseCatalog.self) private var catalog
    @Environment(\.colorScheme) private var colorScheme

    // Which exercise is currently "expanded" (Model C).
    @State private var currentExerciseId: UUID?
    @State private var confirmDiscard = false

    // Fetch UserPreferences for display unit. Singleton by convention.
    @Query private var prefs: [UserPreferences]
    private var displayUnit: DisplayUnit { prefs.first?.unit ?? .kg }

    private var orderedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    private var currentExercise: SessionExercise? {
        guard let id = currentExerciseId else { return orderedExercises.first }
        return orderedExercises.first { $0.id == id } ?? orderedExercises.first
    }

    private var currentPrimaryMuscle: MuscleGroup? {
        guard let ce = currentExercise,
              let exercise = catalog.exercise(withId: ce.exerciseId) else { return nil }
        return exercise.primaryMuscles.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MuscleTint.cardGradient(
                    for: currentPrimaryMuscle,
                    colorScheme: colorScheme
                )
                // The ambient background is the only thing carrying the
                // muscle tint now. The expanded card stays neutral, so weights
                // and reps sit on a plain surface — mid-set you need the
                // numbers legible, not decorated.
                .opacity(0.7)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.4), value: currentPrimaryMuscle)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(orderedExercises) { se in
                                if se.id == currentExercise?.id {
                                    ExpandedExerciseSection(
                                        sessionExercise: se,
                                        displayUnit: displayUnit,
                                        currentSetOrder: currentSetOrder(for: se),
                                        onSetSkipToggled: { set in toggleSkip(set) },
                                        onSetDeleted: { set in deleteSet(set) },
                                        onAddSet: { addSet(to: se) },
                                        onExerciseFinished: {
                                            advanceToNextExercise(after: se, proxy: proxy)
                                        }
                                    )
                                    .id(se.id)
                                } else {
                                    CollapsedExerciseRow(
                                        sessionExercise: se,
                                        onTap: {
                                            withAnimation(.smooth(duration: 0.3)) {
                                                currentExerciseId = se.id
                                            }
                                        }
                                    )
                                    .id(se.id)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle(session.workoutNameSnapshot ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleWithTimer
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            confirmDiscard = true
                        } label: {
                            Label("Discard Workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finish()
                    } label: {
                        Text("Finish")
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Discard this workout?", isPresented: $confirmDiscard) {
                Button("Discard", role: .destructive) {
                    onDiscard()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Any sets you've logged will be lost.")
            }
            .onAppear {
                if currentExerciseId == nil, let first = orderedExercises.first {
                    currentExerciseId = first.id
                }
                Haptics.workoutStarted()
            }
        }
    }

    // MARK: - Toolbar title

    /// Workout name over a live elapsed-time readout. `Text(_:style:.timer)`
    /// self-updates once a second without a `Timer` of our own.
    private var titleWithTimer: some View {
        VStack(spacing: 0) {
            Text(session.workoutNameSnapshot ?? "Workout")
                .font(.headline)
                .lineLimit(1)
            Text(session.startedAt, style: .timer)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    /// Expand the next exercise that still has unlogged sets, and scroll it
    /// into view. Called when the last set of the current exercise is logged.
    private func advanceToNextExercise(after se: SessionExercise, proxy: ScrollViewProxy) {
        let list = orderedExercises
        guard let index = list.firstIndex(where: { $0.id == se.id }) else { return }
        guard let next = list[(index + 1)...].first(where: hasRemainingSets) else { return }

        withAnimation(.smooth(duration: 0.3)) {
            currentExerciseId = next.id
            proxy.scrollTo(next.id, anchor: .top)
        }
    }

    private func hasRemainingSets(_ se: SessionExercise) -> Bool {
        (se.sets ?? []).contains { $0.completedAt == nil && !$0.skipped }
    }

    /// Order of the first not-yet-completed non-skipped set.
    private func currentSetOrder(for se: SessionExercise) -> Int {
        let sets = (se.sets ?? []).sorted { $0.order < $1.order }
        for s in sets where s.completedAt == nil && !s.skipped {
            return s.order
        }
        return sets.last?.order ?? 0
    }

    private func toggleSkip(_ set: WorkSet) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            set.skipped.toggle()
            if set.skipped {
                set.completedAt = nil
            }
        }
        Haptics.setSkipped()
    }

    private func deleteSet(_ set: WorkSet) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            modelContext.delete(set)
        }
    }

    private func addSet(to se: SessionExercise) {
        let sets = (se.sets ?? []).sorted { $0.order < $1.order }
        let nextOrder = (sets.map(\.order).max() ?? -1) + 1
        // Seed the new set from the previous set's values (nice-to-have).
        let last = sets.last
        let set = WorkSet(
            order: nextOrder,
            weightKg: last?.weightKg ?? 0,
            reps: last?.reps ?? 0,
            rir: nil
        )
        set.sessionExercise = se
        modelContext.insert(set)
    }

    private func finish() {
        Haptics.workoutEnded()
        SessionLifecycle.end(session)
        onFinish(session)
    }
}
