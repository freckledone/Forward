import SwiftUI

/// Root TabView per D-019. Three tabs: Workouts / History / Progress.
/// Settings lives inside the Workouts tab's toolbar (gear icon) per D-019.
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
    }
}
