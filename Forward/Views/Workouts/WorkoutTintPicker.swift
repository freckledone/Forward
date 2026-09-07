import SwiftUI

/// Horizontal-scrolling row of color chips for choosing a Workout's tint.
/// First chip is "Auto" (nil → derive from first exercise). The rest are
/// pure color swatches taken from the `MuscleTint` palette — no muscle
/// labels, because the color is meant as workout identity, not a semantic
/// muscle association.
struct WorkoutTintPicker: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                autoChip
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    colorChip(for: muscle)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    // MARK: - Chips

    private var autoChip: some View {
        Button {
            selection = nil
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .tertiarySystemFill))
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 36, height: 36)
            .overlay {
                if selection == nil {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2.5)
                        .padding(-4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Auto tint")
    }

    private func colorChip(for muscle: MuscleGroup) -> some View {
        Button {
            selection = muscle
        } label: {
            Circle()
                .fill(MuscleTint.color(for: muscle))
                .frame(width: 36, height: 36)
                .overlay {
                    if selection == muscle {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .padding(-4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(muscle.displayName) tint")
    }
}
