import Foundation

// Values match docs/06-exercise-database-specification.md §2 (D-036, amended by D-046).
// String-backed for CloudKit schema stability and JSON round-trip.

enum LoadingMode: String, Codable, CaseIterable, Hashable {
    case weighted
    case bodyweight
    /// Held for time rather than counted in reps — planks, hangs, carries.
    /// A timed set records a duration; `weightKg` still means *added* weight.
    case timed
}

extension LoadingMode {
    var displayName: String {
        switch self {
        case .weighted: return "Weighted"
        case .bodyweight: return "Bodyweight"
        case .timed: return "Timed"
        }
    }

    /// True when a set is measured in seconds instead of reps.
    var isTimed: Bool { self == .timed }
}

enum MuscleGroup: String, Codable, CaseIterable, Hashable {
    case chest, back, lats, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves
    case core, forearms, traps
}

enum Equipment: String, Codable, CaseIterable, Hashable {
    case barbell, dumbbell, cable
    case machine              // selectorized / pin-loaded / stack-loaded
    case plateLoadedMachine   // Hammer Strength-style, plate-loaded hip thrust / leg press / calf raise
    case bodyweight, kettlebell, band, ezBar
}

enum MovementPattern: String, Codable, CaseIterable, Hashable {
    case push, pull, squat, hinge, lunge, carry, isolate
}

enum DisplayUnit: String, Codable, CaseIterable, Hashable {
    case kg, lb
}

// MARK: - Display names

extension Equipment {
    /// Human-readable name for filters, chips, and detail rows.
    /// Kept short enough that filter pills don't overflow horizontally.
    var displayName: String {
        switch self {
        case .ezBar: return "EZ Bar"
        case .plateLoadedMachine: return "Plate-loaded"
        default: return rawValue.capitalized
        }
    }
}

extension MuscleGroup {
    /// Human-readable name for filters, chips, and detail rows.
    var displayName: String { rawValue.capitalized }
}
