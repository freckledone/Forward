import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity for a workout in progress (D-074).
///
/// Between sets the phone is face-down on a bench. This is the one place the
/// app can be useful without being opened: how long you've been training, what
/// you're on, and how much of it is left.
///
/// Every elapsed time is rendered with `.timer` from the session's start date
/// rather than pushed as state, so the clock stays live without the app
/// spending its update budget to say what the date already implies.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.workoutName)
                            .font(.caption)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "dumbbell.fill")
                    }
                    .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .frame(maxWidth: 74, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(context.state.setsLabel)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    SetProgressBar(
                        completed: context.state.completedSets,
                        total: context.state.totalSets
                    )
                    .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
            } compactTrailing: {
                Text(context.attributes.startedAt, style: .timer)
                    .monospacedDigit()
                    // The compact region is tiny; without a cap the timer
                    // pushes the leading icon out once it passes an hour.
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
            .keylineTint(Color.accentColor)
        }
    }

    // MARK: - Lock Screen

    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.attributes.workoutName)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .fixedSize()
            }

            HStack(alignment: .firstTextBaseline) {
                Text(context.state.exerciseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(context.state.exerciseLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            SetProgressBar(
                completed: context.state.completedSets,
                total: context.state.totalSets
            )
        }
        .padding(16)
    }
}

/// One segment per set, filled as they're logged.
///
/// A bar rather than the app's dots: at a glance on a Lock Screen, from across
/// a bench, proportion reads faster than a count of small circles.
private struct SetProgressBar: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < completed ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) sets done")
    }
}
