import Testing
import Foundation
@testable import Further

/// The bundled catalog is loaded once at launch and a bad file is fatal:
/// `load()` builds its index with `Dictionary(uniqueKeysWithValues:)`, which
/// traps on a duplicate id. These tests turn "the app opens empty" and "the app
/// crashes on launch" into test failures instead.
@MainActor
@Suite("ExerciseCatalog")
struct ExerciseCatalogTests {

    static let catalog = ExerciseCatalog()

    // MARK: - The bundled file

    @Test("The bundle actually loads")
    func bundleLoads() {
        #expect(!Self.catalog.all.isEmpty)
        #expect(Self.catalog.all.count == Self.catalog.byId.count)
    }

    @Test("Every id is unique — a duplicate would trap at launch")
    func idsAreUnique() {
        let ids = Self.catalog.all.map(\.id)
        let duplicates = Dictionary(grouping: ids, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        #expect(duplicates.isEmpty, "duplicate exercise ids: \(duplicates)")
    }

    @Test("No entry has an empty id, name, or primary muscle")
    func entriesAreWellFormed() {
        let blankId = Self.catalog.all.filter { $0.id.trimmingCharacters(in: .whitespaces).isEmpty }
        let blankName = Self.catalog.all.filter { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        let noMuscle = Self.catalog.all.filter { $0.primaryMuscles.isEmpty }

        #expect(blankId.isEmpty)
        #expect(blankName.map(\.id).isEmpty, "unnamed: \(blankName.map(\.id))")
        // Muscle drives card tints and the Progress dashboard.
        #expect(noMuscle.map(\.id).isEmpty, "no primary muscle: \(noMuscle.map(\.id).prefix(10))")
    }

    @Test("Aliases are lowercase, since search lowercases the query before matching")
    func aliasesAreLowercase() {
        let offenders = Self.catalog.all
            .filter { $0.aliases.contains { $0 != $0.lowercased() } }
            .map(\.id)
        #expect(offenders.isEmpty, "aliases with uppercase: \(offenders.prefix(10))")
    }

    @Test("Catalog is alphabetical, so an unfiltered browse is ordered")
    func sortedAlphabetically() {
        let names = Self.catalog.all.map { $0.name.lowercased() }
        #expect(names == names.sorted())
    }

    // MARK: - Lookup

    @Test("Lookup by id round-trips, and unknown ids return nil")
    func lookup() throws {
        let first = try #require(Self.catalog.all.first)
        #expect(Self.catalog.exercise(withId: first.id)?.id == first.id)
        #expect(Self.catalog.exercise(withId: "not-a-real-exercise") == nil)
    }

    // MARK: - Search and filter

    @Test("Empty query with no filters returns everything")
    func emptyQueryReturnsAll() {
        #expect(Self.catalog.exercises().count == Self.catalog.all.count)
    }

    @Test("Whitespace-only query counts as empty")
    func whitespaceQueryReturnsAll() {
        #expect(Self.catalog.exercises(matching: "   ").count == Self.catalog.all.count)
    }

    @Test("Among entries with no alias hits, a prefix match outranks a mid-name match")
    func prefixOutranksContains() throws {
        // Restricted to entries with no alias hits, because aliases are worth
        // +3 each and can legitimately lift a mid-name match past a prefix one
        // (docs/06 §6). Compared at equal alias weight, prefix must still win.
        let results = Self.catalog
            .exercises(matching: "bench")
            .filter { !$0.aliases.contains { $0.contains("bench") } }
        try #require(!results.isEmpty)

        let firstMidName = results.firstIndex { !$0.name.lowercased().hasPrefix("bench") }
        let lastPrefixed = results.lastIndex { $0.name.lowercased().hasPrefix("bench") }

        if let firstMidName, let lastPrefixed {
            #expect(lastPrefixed < firstMidName, "prefix matches must sort ahead")
        }
    }

    @Test("Alias weight surfaces the canonical lift ahead of an incidental prefix match")
    func aliasesSurfaceTheCanonicalLift() throws {
        // "bench" should return the bench press, not "Bench Dips" — which is
        // exactly what the +3-per-alias rule buys.
        let top = try #require(Self.catalog.exercises(matching: "bench").first)
        #expect(
            top.aliases.contains { $0.contains("bench") },
            "expected an alias-boosted entry first, got \(top.name)"
        )
    }

    @Test("Search is case-insensitive")
    func searchIgnoresCase() {
        let lower = Self.catalog.exercises(matching: "squat").map(\.id)
        let upper = Self.catalog.exercises(matching: "SQUAT").map(\.id)
        #expect(lower == upper)
        #expect(!lower.isEmpty)
    }

    @Test("Nonsense queries return nothing rather than everything")
    func noMatches() {
        #expect(Self.catalog.exercises(matching: "zzzqqqxxx").isEmpty)
    }

    @Test("Muscle filter only returns that primary muscle")
    func muscleFilter() throws {
        let results = Self.catalog.exercises(muscle: .chest)
        try #require(!results.isEmpty)
        #expect(results.allSatisfy { $0.primaryMuscles.contains(.chest) })
    }

    @Test("Equipment filter only returns that equipment")
    func equipmentFilter() throws {
        let results = Self.catalog.exercises(equipment: .barbell)
        try #require(!results.isEmpty)
        #expect(results.allSatisfy { $0.equipment.contains(.barbell) })
    }

    @Test("Muscle and equipment filters AND together, not OR")
    func filtersCombine() throws {
        let both = Self.catalog.exercises(muscle: .chest, equipment: .barbell)
        try #require(!both.isEmpty)
        #expect(both.allSatisfy { $0.primaryMuscles.contains(.chest) && $0.equipment.contains(.barbell) })
        #expect(both.count <= Self.catalog.exercises(muscle: .chest).count)
    }

    @Test("Query and filter apply together")
    func queryRespectsFilter() {
        let results = Self.catalog.exercises(matching: "press", muscle: .chest)
        #expect(results.allSatisfy { $0.primaryMuscles.contains(.chest) })
        #expect(results.allSatisfy {
            $0.name.lowercased().contains("press") || $0.aliases.contains { $0.contains("press") }
        })
    }

    @Test("Every muscle group has at least one exercise, so no filter chip is a dead end")
    func everyMuscleHasExercises() {
        let empty = MuscleGroup.allCases.filter { Self.catalog.exercises(muscle: $0).isEmpty }
        #expect(empty.isEmpty, "muscle filters with no results: \(empty)")
    }
}
