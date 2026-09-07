import SwiftUI

/// A row in the WorkoutEditor showing one exercise's name and its
/// sets × rep-range target.
///
/// Tap the row to reveal an inline picker panel with accent-tinted pill
/// menus for Sets, Reps min, and Reps max — the modern iOS pattern (Menu
/// pickers rather than steppers). Rep range is stored as min + max per
/// D-039; when equal, the UI collapses to a single number.
struct WorkoutExerciseRow: View {
    @Bindable var workoutExercise: WorkoutExercise
    @Environment(ExerciseCatalog.self) private var catalog

    @State private var expanded = false

    private var exerciseName: String {
        catalog.exercise(withId: workoutExercise.exerciseId)?.name ?? "Unknown exercise"
    }

    private var setsRepsLabel: String {
        let reps: String
        if workoutExercise.targetRepsMin == workoutExercise.targetRepsMax {
            reps = "\(workoutExercise.targetRepsMin)"
        } else {
            reps = "\(workoutExercise.targetRepsMin)–\(workoutExercise.targetRepsMax)"
        }
        return "\(workoutExercise.targetSets) × \(reps)"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 20) {
                setsPicker
                repsRangePicker
            }
            .padding(.vertical, 12)
        } label: {
            HStack {
                Text(exerciseName)
                    .foregroundStyle(.primary)
                Spacer()
                Text(setsRepsLabel)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(expanded ? Color.accentColor : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: expanded)
            }
        }
    }

    // MARK: - Sets

    private var setsPicker: some View {
        HStack(alignment: .center, spacing: 12) {
            fieldLabel("Sets")
            Spacer()
            valueChip(
                value: workoutExercise.targetSets,
                range: 1...20
            ) { workoutExercise.targetSets = $0 }
        }
    }

    // MARK: - Reps range

    private var repsRangePicker: some View {
        HStack(alignment: .center, spacing: 12) {
            fieldLabel("Reps")
            Spacer()
            HStack(spacing: 6) {
                valueChip(
                    value: workoutExercise.targetRepsMin,
                    range: 1...50
                ) { newValue in
                    workoutExercise.targetRepsMin = newValue
                    if newValue > workoutExercise.targetRepsMax {
                        workoutExercise.targetRepsMax = newValue
                    }
                }
                Text("–")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.tertiary)
                valueChip(
                    value: workoutExercise.targetRepsMax,
                    range: 1...50
                ) { newValue in
                    workoutExercise.targetRepsMax = newValue
                    if newValue < workoutExercise.targetRepsMin {
                        workoutExercise.targetRepsMin = newValue
                    }
                }
            }
        }
    }

    // MARK: - Pieces

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private func valueChip(
        value: Int,
        range: ClosedRange<Int>,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        Menu {
            ForEach(range, id: \.self) { n in
                Button {
                    onSelect(n)
                } label: {
                    if n == value {
                        Label("\(n)", systemImage: "checkmark")
                    } else {
                        Text("\(n)")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 40)
            .fixedSize(horizontal: true, vertical: false)
            .background {
                Capsule().fill(Color.accentColor.opacity(0.14))
            }
        }
        .buttonStyle(.plain)
    }
}
