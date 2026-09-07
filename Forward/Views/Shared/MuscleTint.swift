import SwiftUI

/// Muscle-group color palette per Design System §2 / §7 (D-043).
///
/// Each `MuscleGroup` maps to a base `Color` used as a subtle tint on Progress
/// cards, template cards, and the Active Workout background. Applied via
/// `.gradient(for:)` which returns a `LinearGradient` at low opacity so the
/// tint reads as background flavor, not as a color-block.
///
/// Final hex values will be tuned during the first visual pass. For now these
/// use SwiftUI system colors + hex fallbacks so the app has a coherent look
/// before an Assets.xcassets pass.
nonisolated enum MuscleTint {

    // MARK: - Base color per group

    static func color(for group: MuscleGroup) -> Color {
        switch group {
        case .chest:      return Color(red: 0.98, green: 0.62, blue: 0.44)  // warm peach
        case .back:       return Color(red: 0.35, green: 0.53, blue: 0.72)  // steel blue
        case .lats:       return Color(red: 0.20, green: 0.60, blue: 0.60)  // deep teal
        case .shoulders:  return Color(red: 0.92, green: 0.72, blue: 0.28)  // gold
        case .biceps:     return Color(red: 0.42, green: 0.72, blue: 0.42)  // leaf green
        case .triceps:    return Color(red: 0.26, green: 0.52, blue: 0.34)  // forest green
        case .quads:      return Color(red: 0.55, green: 0.38, blue: 0.78)  // violet
        case .hamstrings: return Color(red: 0.60, green: 0.32, blue: 0.55)  // plum
        case .glutes:     return Color(red: 0.90, green: 0.48, blue: 0.60)  // rose
        case .calves:     return Color(red: 0.78, green: 0.65, blue: 0.42)  // sand
        case .core:       return Color(red: 0.44, green: 0.50, blue: 0.56)  // slate
        case .forearms:   return Color(red: 0.78, green: 0.46, blue: 0.28)  // copper
        case .traps:      return Color(red: 0.68, green: 0.44, blue: 0.28)  // bronze
        }
    }

    /// Base color for a template = tint of its FIRST exercise's first primary
    /// muscle. If empty, falls back to a neutral accent-tinted background.
    static func color(forFirst muscle: MuscleGroup?) -> Color? {
        muscle.map(color(for:))
    }

    // MARK: - Card background gradients

    /// Subtle tinted gradient for a card background per §2 (light: 10%→4%;
    /// dark: 14%→6%). Layered over `secondarySystemGroupedBackground`.
    static func cardGradient(for group: MuscleGroup?, colorScheme: ColorScheme) -> LinearGradient {
        let base = group.map(color(for:)) ?? Color.accentColor
        let topOpacity: Double = colorScheme == .dark ? 0.14 : 0.10
        let bottomOpacity: Double = colorScheme == .dark ? 0.06 : 0.04
        return LinearGradient(
            colors: [base.opacity(topOpacity), base.opacity(bottomOpacity)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
