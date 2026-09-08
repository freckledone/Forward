import SwiftUI
import WidgetKit

/// Only a Live Activity ships here.
///
/// Xcode's template also scaffolds a home-screen widget and a Control Widget.
/// Both were removed: a workout tracker has nothing useful to say on the home
/// screen between sessions, and shipping placeholder surface would be the
/// feature-for-its-own-sake the constitution rules out.
@main
struct FurtherWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
