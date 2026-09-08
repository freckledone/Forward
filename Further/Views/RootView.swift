import SwiftUI

/// Root TabView per D-019. Three tabs: Workouts / History / Progress.
/// Settings lives inside the Workouts tab's toolbar (gear icon) per D-019.
///
/// `.hierarchical` symbol rendering is set once here rather than per-symbol,
/// because Design System §5 makes it the app-wide default. It gives SF Symbols
/// their layered depth instead of flat single-colour fills.
///
/// Note on tab icons: §5 asks for `.palette` (accent + secondary) on the
/// Workouts icon. That isn't achievable with a standard `TabView` — UIKit
/// template-renders tab bar items and applies the tint itself, discarding any
/// per-layer colour. Getting it would mean hand-building the tab bar, which
/// §1 ("we do not reinvent Apple's UI") rules out for a decorative gain.
struct RootView: View {
    var body: some View {
        TabView {
            WorkoutsRoot()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }

            HistoryRoot()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            ProgressRoot()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .symbolRenderingMode(.hierarchical)
    }
}
