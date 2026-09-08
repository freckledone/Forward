import Foundation

/// Weight is stored canonically in kilograms per D-004. Display conversion to
/// pounds happens here, and only for display — the stored value is never
/// mutated on a unit-preference change.
enum UnitConversion {

    // Exact conversion factor. Do not round these constants.
    static let kgPerLb: Double = 0.45359237
    static let lbPerKg: Double = 1.0 / 0.45359237  // ≈ 2.2046226218

    static func lb(fromKg kg: Double) -> Double { kg * lbPerKg }
    static func kg(fromLb lb: Double) -> Double { lb * kgPerLb }

    // MARK: - Display

    /// Format a stored kg value for display in the user's preferred unit.
    /// Rounding:
    ///   - kg: nearest 0.5 (common barbell / plate math)
    ///   - lb: nearest whole pound
    /// Whole numbers omit the fractional part (`100 kg`, not `100.0 kg`).
    static func display(weightKg: Double, unit: DisplayUnit) -> String {
        switch unit {
        case .kg:
            return displayKg(weightKg)
        case .lb:
            return displayLb(lb(fromKg: weightKg))
        }
    }

    private static func displayKg(_ v: Double) -> String {
        let rounded = (v * 2).rounded() / 2
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded)) kg"
        }
        return String(format: "%.1f kg", rounded)
    }

    private static func displayLb(_ v: Double) -> String {
        let rounded = v.rounded()
        return "\(Int(rounded)) lb"
    }
}
