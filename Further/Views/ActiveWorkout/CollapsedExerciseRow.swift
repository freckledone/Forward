import SwiftUI

/// Compact row for a non-current exercise during Active Workout (Model C).
/// Tap to make this the current exercise.
///
/// Progress is shown as one dot per set rather than a "1/3" ratio. Mid-workout
/// you read this at arm's length, between sets, and a ratio has to be *read* —
/// dots are counted by the eye. The constitution asks the app to disappear
/// while you train; making you parse text works against that.
struct CollapsedExerciseRow: View {
    let sessionExercise: SessionExercise
    let onTap: () -> Void

    private var orderedSets: [WorkSet] {
        (sessionExercise.sets ?? []).sorted { $0.order < $1.order }
    }

    private var completedSets: Int {
        orderedSets.filter { $0.completedAt != nil }.count
    }

    private var isFullyDone: Bool {
        !orderedSets.isEmpty && orderedSets.allSatisfy { $0.completedAt != nil || $0.skipped }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                statusIcon

                Text(sessionExercise.exerciseNameSnapshot)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                // No chevron: tapping expands this row in place rather than
                // pushing a screen, so a disclosure indicator would promise
                // navigation that never happens.
                setDots
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sessionExercise.exerciseNameSnapshot)
        .accessibilityValue("\(completedSets) of \(orderedSets.count) sets done")
        .accessibilityAddTraits(.isButton)
    }

    private var statusIcon: some View {
        Image(systemName: isFullyDone ? "checkmark.circle.fill" : "circle.dashed")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isFullyDone ? Color.accentColor : Color.secondary)
    }

    /// One dot per set: filled for logged, hollow for skipped, faint for
    /// still to come.
    private var setDots: some View {
        HStack(spacing: 5) {
            ForEach(orderedSets) { set in
                dot(for: set)
            }
        }
        .animation(.smooth(duration: 0.2), value: completedSets)
    }

    @ViewBuilder
    private func dot(for set: WorkSet) -> some View {
        if set.completedAt != nil {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
        } else if set.skipped {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1)
                .frame(width: 7, height: 7)
        } else {
            Circle()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 7, height: 7)
        }
    }
}
