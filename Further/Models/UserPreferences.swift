import Foundation
import SwiftData

/// Singleton-by-convention: query for the single record, create if none exists.
///
/// `displayUnit` is stored as a String rather than the `DisplayUnit` enum
/// directly, for CloudKit schema stability (D-030). Access it via the
/// computed `unit` property, not the raw string.
@Model
final class UserPreferences {
    var id: UUID = UUID()
    var displayUnitRaw: String = DisplayUnit.kg.rawValue
    var healthKitEnabled: Bool = false

    init() {
        self.id = UUID()
        self.displayUnitRaw = DisplayUnit.kg.rawValue
        self.healthKitEnabled = false
    }

    var unit: DisplayUnit {
        get { DisplayUnit(rawValue: displayUnitRaw) ?? .kg }
        set { displayUnitRaw = newValue.rawValue }
    }
}
