import SwiftUI

/// Compact row for a non-current exercise during Active Workout (Model C).
/// Shows name + set-completion progress. Tap to make this the current exercise.
struct CollapsedExerciseRow: View {
    let sessionExercise: SessionExercise
    let onTap: () -> Void

    private var totalSets: Int { (sessionExercise.sets ?? []).count }
    private var completedSets: Int {
        (sessionExercise.sets ?? []).filter { $0.completedAt != nil }.count
    }
    private var isFullyDone: Bool { totalSets > 0 && completedSets == totalSets }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                statusIcon
                Text(sessionExercise.exerciseNameSnapshot)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                // No chevron: tapping expands this row in place, it does not
                // push a screen. A disclosure indicator would promise
                // navigation that never happens.
                Text("\(completedSets)/\(totalSets)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: some View {
        Image(systemName: isFullyDone ? "checkmark.circle.fill" : "circle.dashed")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isFullyDone ? Color.accentColor : Color.secondary)
    }
}
