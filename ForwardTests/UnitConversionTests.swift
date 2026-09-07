import Testing
@testable import Forward

@Suite("UnitConversion")
struct UnitConversionTests {

    // MARK: - Roundtrip precision

    @Test("kg → lb → kg roundtrip is exact")
    func kgLbRoundtripExact() {
        // The exact conversion constants are inverses, so a roundtrip should
        // return the exact original within floating-point tolerance.
        for kg in stride(from: 0.0, through: 500.0, by: 2.5) {
            let lb = UnitConversion.lb(fromKg: kg)
            let back = UnitConversion.kg(fromLb: lb)
            #expect(abs(back - kg) < 1e-9)
        }
    }

    @Test("Common gym weights convert to expected pounds")
    func commonKgToLb() {
        // Sanity checks for values a lifter would recognize.
        #expect(UnitConversion.lb(fromKg: 20).rounded() == 44)     // Olympic bar
        #expect(UnitConversion.lb(fromKg: 100).rounded() == 220)   // 100 kg
        #expect(UnitConversion.lb(fromKg: 45).rounded() == 99)     // ~45 kg plate is ~99 lb
    }

    // MARK: - Display formatting

    @Test("Whole-kg display omits decimal")
    func wholeKgDisplay() {
        #expect(UnitConversion.display(weightKg: 100, unit: .kg) == "100 kg")
        #expect(UnitConversion.display(weightKg: 0, unit: .kg) == "0 kg")
    }

    @Test("Half-kg display shows one decimal")
    func halfKgDisplay() {
        #expect(UnitConversion.display(weightKg: 102.5, unit: .kg) == "102.5 kg")
        #expect(UnitConversion.display(weightKg: 2.5, unit: .kg) == "2.5 kg")
    }

    @Test("kg display rounds to nearest 0.5")
    func kgRoundsToHalfKg() {
        // 100.3 → nearest 0.5 = 100.5
        #expect(UnitConversion.display(weightKg: 100.3, unit: .kg) == "100.5 kg")
        // 100.24 → nearest 0.5 = 100
        #expect(UnitConversion.display(weightKg: 100.24, unit: .kg) == "100 kg")
    }

    @Test("lb display rounds to whole pounds")
    func lbRoundsToWhole() {
        // 100 kg = 220.46 lb → 220
        #expect(UnitConversion.display(weightKg: 100, unit: .lb) == "220 lb")
        // 45 kg = 99.21 lb → 99
        #expect(UnitConversion.display(weightKg: 45, unit: .lb) == "99 lb")
    }

    @Test("Zero weight is handled consistently")
    func zeroWeight() {
        #expect(UnitConversion.display(weightKg: 0, unit: .kg) == "0 kg")
        #expect(UnitConversion.display(weightKg: 0, unit: .lb) == "0 lb")
    }
}
