import SwiftUI

/// Horizontal-scrolling row of color chips for choosing a Workout's tint.
/// First chip is "Auto" (nil → derive from first exercise). The rest are pure
/// color swatches from the `MuscleTint` palette — no muscle labels, because
/// the color is meant as workout identity, not a semantic muscle association.
///
/// Each chip reserves a frame big enough to contain its own selection ring.
/// Drawing the ring outside the frame (an overlay with negative padding) gets
/// clipped by the ScrollView at the leading edge, so the first chip loses its
/// ring — the selected state would silently disappear exactly when Auto, the
/// default, is chosen.
struct WorkoutTintPicker: View {
    @Binding var selection: MuscleGroup?

    /// Swatch diameter. The chip frame is larger to leave room for the ring.
    private let swatch: CGFloat = 36
    /// Ring sits on the frame edge, `ringInset` away from the swatch.
    private let ringInset: CGFloat = 6

    private var chipSize: CGFloat { swatch + ringInset * 2 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // Zero spacing: each chip already carries `ringInset` of padding
            // on both sides, which reads as the gap between swatches.
            HStack(spacing: 0) {
                autoChip
                ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                    colorChip(for: muscle)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    // MARK: - Chips

    private var autoChip: some View {
        chip(isSelected: selection == nil) {
            selection = nil
        } content: {
            ZStack {
                Circle().fill(Color(uiColor: .tertiarySystemFill))
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Automatic tint")
        .accessibilityAddTraits(selection == nil ? [.isSelected] : [])
    }

    private func colorChip(for muscle: MuscleGroup) -> some View {
        chip(isSelected: selection == muscle) {
            selection = muscle
        } content: {
            Circle().fill(MuscleTint.color(for: muscle))
        }
        .accessibilityLabel("\(muscle.displayName) tint")
        .accessibilityAddTraits(selection == muscle ? [.isSelected] : [])
    }

    /// Swatch centered in a frame that also contains the selection ring, so
    /// the whole chip — selected or not — occupies identical space and the
    /// row never shifts as the selection moves.
    private func chip<Content: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .opacity(isSelected ? 1 : 0)

                content()
                    .frame(width: swatch, height: swatch)
            }
            .frame(width: chipSize, height: chipSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}
