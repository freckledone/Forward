import SwiftUI

/// The single definition of a card surface (Design System §4: 20pt continuous).
///
/// Before this existed the same background/clip/shadow stack was repeated in
/// four views, and had already drifted — one card was 22pt while the spec and
/// its siblings were 20pt.
///
/// Elevation is expressed differently per appearance. A black drop shadow is
/// invisible against a near-black background, so dark mode gets a hairline
/// top-light border instead — which is how iOS itself separates stacked dark
/// surfaces. Light mode keeps the soft shadow.
struct CardSurface: ViewModifier {
    var tint: MuscleGroup?
    var cornerRadius: CGFloat = 20

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        shape.fill(MuscleTint.cardGradient(for: tint, colorScheme: colorScheme))
                    }
            }
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    .opacity(colorScheme == .dark ? 1 : 0)
            }
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 8,
                y: 3
            )
    }
}

extension View {
    /// Applies the standard card background, corner radius, and elevation.
    /// Pass `tint` to layer the muscle-group gradient (Design System §2).
    func cardSurface(tint: MuscleGroup? = nil, cornerRadius: CGFloat = 20) -> some View {
        modifier(CardSurface(tint: tint, cornerRadius: cornerRadius))
    }
}
