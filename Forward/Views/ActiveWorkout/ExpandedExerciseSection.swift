import SwiftUI
import SwiftData

/// The "current exercise" card in Active Workout (Model C, D-012).
///
/// Header: exercise name, muscle chip, target (e.g. "3 × 6–8"), a "Last"
/// reference pill showing the heaviest past set that landed inside the target
/// rep range, and a swap button for changing the exercise mid-session.
///
/// Body: all sets as `WorkSetRow`s, plus an Add Set button.
///
/// This view owns the keyboard focus for its whole set grid so that completing
/// a set can advance focus to the next set's weight field (a `WorkSetRow`
/// can't reach its sibling's `@FocusState`).
struct ExpandedExerciseSection: View {
    @Bindable var sessionExercise: SessionExercise
    let displayUnit: DisplayUnit
    let currentSetOrder: Int
    let onSetSkipToggled: (WorkSet) -> Void
    let onSetDeleted: (WorkSet) -> Void
    let onAddSet: () -> Void
    /// Fired when the last remaining set of this exercise is completed.
    let onExerciseFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(ExerciseCatalog.self) private var catalog

    @FocusState private var focusedField: SetFieldFocus?

    @State private var recentBest: ProgressCalculator.RecentBest?
    @State private var swapPresented = false

    private let engine: SuggestionEngine = LastSessionSuggestionEngine()

    private var exercise: Exercise? {
        catalog.exercise(withId: sessionExercise.exerciseId)
    }

    private var primaryMuscle: MuscleGroup? {
        exercise?.primaryMuscles.first
    }

    private var orderedSets: [WorkSet] {
        (sessionExercise.sets ?? []).sorted { $0.order < $1.order }
    }

    /// Target rep range, or nil when the workout never specified one.
    private var targetRepRange: ClosedRange<Int>? {
        let minR = sessionExercise.targetRepsMin
        let maxR = sessionExercise.targetRepsMax
        let lower = min(minR, maxR)
        let upper = max(minR, maxR)
        guard upper > 0 else { return nil }
        return max(lower, 1)...upper
    }

    private var targetLabel: String? {
        let sets = sessionExercise.targetSets
        let minR = sessionExercise.targetRepsMin
        let maxR = sessionExercise.targetRepsMax
        guard sets > 0 else { return nil }
        let repsLabel: String
        if minR == maxR {
            guard minR > 0 else { return nil }
            repsLabel = "\(minR)"
        } else if minR == 0 {
            repsLabel = "\(maxR)"
        } else {
            repsLabel = "\(minR)–\(maxR)"
        }
        return "\(sets) × \(repsLabel)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
                .padding(.horizontal, 4)
            setsList
            addSetButton
                .padding(.horizontal, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(tint: primaryMuscle)
        .sheet(isPresented: $swapPresented) {
            ExercisePicker { picked in
                swap(to: picked)
            }
        }
        // Re-runs when the exercise is swapped, refreshing the "Last" pill.
        .task(id: sessionExercise.exerciseId) {
            recentBest = ProgressCalculator.recentBest(
                for: sessionExercise.exerciseId,
                targetReps: targetRepRange,
                excluding: sessionExercise.session?.id,
                in: modelContext
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sessionExercise.exerciseNameSnapshot)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 4)

                swapButton
            }

            // Horizontal scroll so a long muscle + target + last combination
            // never squeezes the pills into vertical letter-stacking.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let muscle = primaryMuscle {
                        pill(text: muscle.displayName, tint: .secondary)
                    }
                    if let target = targetLabel {
                        pill(text: "Target \(target)", tint: .primary)
                    }
                    if let best = recentBest {
                        lastPill(best)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    /// Straight to the picker — swapping is the only exercise-level action
    /// during a session, so a menu would be a tap of pure ceremony.
    private var swapButton: some View {
        Button {
            swapPresented = true
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swap exercise")
    }

    private func pill(text: String, tint: HierarchicalShapeStyle) -> some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(Color(uiColor: .tertiarySystemFill))
            }
    }

    /// "Last 100 kg × 8". Accent-tinted when the rep count sat inside the
    /// target range — that's the number worth beating today.
    private func lastPill(_ best: ProgressCalculator.RecentBest) -> some View {
        Text("Last \(weightLabel(best.weightKg)) × \(best.reps)")
            .font(.footnote.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(best.withinTarget ? Color.accentColor : Color.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(
                    best.withinTarget
                        ? Color.accentColor.opacity(0.14)
                        : Color(uiColor: .tertiarySystemFill)
                )
            }
            .accessibilityLabel(
                best.withinTarget
                    ? "Last time in target range, \(weightLabel(best.weightKg)) for \(best.reps) reps"
                    : "Last time, \(weightLabel(best.weightKg)) for \(best.reps) reps"
            )
    }

    /// Locale-independent, unit-aware weight render (matches `WorkSetRow`).
    private func weightLabel(_ kg: Double) -> String {
        let value: Double
        let unit: String
        switch displayUnit {
        case .kg:
            value = kg
            unit = "kg"
        case .lb:
            value = UnitConversion.lb(fromKg: kg)
            unit = "lb"
        }
        let rounded = (value * 10).rounded() / 10
        let number = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
        return "\(number) \(unit)"
    }

    // MARK: - Sets

    private var setsList: some View {
        VStack(spacing: 8) {
            ForEach(orderedSets) { s in
                WorkSetRow(
                    workSet: s,
                    displayUnit: displayUnit,
                    isCurrent: s.order == currentSetOrder && s.completedAt == nil,
                    onCompleteToggled: { advanceFocus(after: s) },
                    onSkipToggled: { onSetSkipToggled(s) },
                    onDelete: { onSetDeleted(s) },
                    focusedField: $focusedField
                )
            }
        }
    }

    private var addSetButton: some View {
        Button {
            Haptics.setAdded()
            onAddSet()
        } label: {
            Label("Add Set", systemImage: "plus.circle")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(.accentColor)
    }

    // MARK: - Actions

    /// After a set is marked complete, put the keyboard on the next unlogged
    /// set's weight field so the user can type straight away. When nothing is
    /// left, drop focus and tell the parent to move on to the next exercise.
    private func advanceFocus(after completed: WorkSet) {
        let sets = orderedSets
        let pending = sets.filter { $0.completedAt == nil && !$0.skipped }

        guard !pending.isEmpty else {
            focusedField = nil
            onExerciseFinished()
            return
        }

        // Prefer the next set below the one just finished; otherwise wrap to
        // the earliest still-unlogged set.
        let next = pending.first { $0.order > completed.order } ?? pending[0]
        let target = SetFieldFocus.weight(next.id)

        // One run-loop hop: the completion mutation re-renders the grid, and
        // setting focus in the same pass gets swallowed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedField = target
        }
    }

    private func swap(to exercise: Exercise) {
        focusedField = nil
        withAnimation(.smooth(duration: 0.25)) {
            SessionLifecycle.swapExercise(
                sessionExercise,
                to: exercise,
                engine: engine,
                context: modelContext
            )
        }
        Haptics.setAdded()
    }
}
