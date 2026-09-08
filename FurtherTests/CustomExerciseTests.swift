import Testing
import SwiftData
import Foundation
@testable import Further

@MainActor
@Suite("CustomExercise")
struct CustomExerciseTests {

    static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: config))
    }

    // MARK: - Slugs

    @Test("Slugs are prefixed, so a custom entry can never shadow a bundled one")
    func slugsArePrefixed() {
        #expect(CustomExercise.makeSlug(from: "Incline Hex Press") == "custom-incline-hex-press")
        #expect(CustomExercise.isCustom("custom-incline-hex-press"))
        #expect(!CustomExercise.isCustom("barbell-bench-press-medium-grip"))
    }

    @Test("Punctuation and runs of spaces collapse to single hyphens")
    func slugsAreClean() {
        #expect(CustomExercise.makeSlug(from: "Z-Press  (seated)") == "custom-z-press-seated")
        #expect(CustomExercise.makeSlug(from: "45° Leg Press") == "custom-45-leg-press")
    }

    @Test("A nameless exercise still gets a unique slug rather than a bare prefix")
    func slugNeverCollapsesToPrefix() {
        let slug = CustomExercise.makeSlug(from: "!!!")
        #expect(slug.hasPrefix("custom-"))
        #expect(slug != "custom-")
    }

    // MARK: - Projection

    @Test("Round-trips through the Exercise projection the rest of the app consumes")
    func projectsToExercise() throws {
        let context = try Self.makeContext()
        let custom = CustomExercise(name: "Incline Hex Press")
        custom.aliases = ["Hex Press", "Squeeze Press"]
        custom.loadingMode = .weighted
        custom.primaryMuscles = [.chest]
        custom.secondaryMuscles = [.triceps, .shoulders]
        custom.equipment = [.dumbbell]
        custom.movementPattern = .push
        custom.instructions = "Squeeze the dumbbells together."
        context.insert(custom)

        let exercise = custom.asExercise
        #expect(exercise.id == "custom-incline-hex-press")
        #expect(exercise.name == "Incline Hex Press")
        #expect(exercise.aliases == ["hex press", "squeeze press"])  // lowercased for search
        #expect(exercise.primaryMuscles == [.chest])
        #expect(exercise.secondaryMuscles == [.triceps, .shoulders])
        #expect(exercise.equipment == [.dumbbell])
        #expect(exercise.movementPattern == .push)
    }

    @Test("Unknown stored enum values are dropped rather than crashing")
    func toleratesUnknownEnumValues() throws {
        let context = try Self.makeContext()
        let custom = CustomExercise(name: "Odd One")
        custom.primaryMusclesRaw = "chest\nnot-a-muscle"
        custom.equipmentRaw = "barbell\nteleporter"
        context.insert(custom)

        #expect(custom.primaryMuscles == [.chest])
        #expect(custom.equipment == [.barbell])
    }

    // MARK: - Catalog integration

    @Test("Custom exercises join the catalog and are findable by search and id")
    func mergesIntoCatalog() throws {
        let context = try Self.makeContext()
        let catalog = ExerciseCatalog()
        let bundledCount = catalog.all.count

        let custom = CustomExercise(name: "Zercher Carry")
        custom.primaryMuscles = [.core]
        custom.equipment = [.barbell]
        context.insert(custom)
        catalog.refreshCustom(from: context)

        #expect(catalog.all.count == bundledCount + 1)
        #expect(catalog.exercise(withId: "custom-zercher-carry")?.name == "Zercher Carry")
        #expect(catalog.exercises(matching: "zercher").contains { $0.id == "custom-zercher-carry" })
        #expect(catalog.exercises(muscle: .core).contains { $0.id == "custom-zercher-carry" })
    }

    @Test("Refreshing twice doesn't duplicate")
    func refreshIsIdempotent() throws {
        let context = try Self.makeContext()
        let catalog = ExerciseCatalog()
        let custom = CustomExercise(name: "Zercher Carry")
        custom.primaryMuscles = [.core]
        context.insert(custom)

        catalog.refreshCustom(from: context)
        let afterFirst = catalog.all.count
        catalog.refreshCustom(from: context)
        #expect(catalog.all.count == afterFirst)
    }

    @Test("The merged catalog stays alphabetical")
    func mergedCatalogStaysSorted() throws {
        let context = try Self.makeContext()
        let catalog = ExerciseCatalog()
        let custom = CustomExercise(name: "Aaa First Alphabetically")
        custom.primaryMuscles = [.core]
        context.insert(custom)
        catalog.refreshCustom(from: context)

        // Not asserting it lands first: the bundled catalog opens with
        // "3/4 Sit-Up", and digits sort ahead of letters.
        let names = catalog.all.map { $0.name.lowercased() }
        #expect(names == names.sorted())

        let index = try #require(catalog.all.firstIndex { $0.id == "custom-aaa-first-alphabetically" })
        if index > 0 {
            #expect(catalog.all[index - 1].name.lowercased() < "aaa first alphabetically")
        }
    }

    // MARK: - Backup

    @Test("Custom exercises survive an export/import round trip")
    func survivesBackupRoundTrip() throws {
        let source = try Self.makeContext()
        let custom = CustomExercise(name: "Incline Hex Press")
        custom.aliases = ["hex press"]
        custom.loadingMode = .timed
        custom.primaryMuscles = [.chest]
        custom.equipment = [.dumbbell]
        custom.instructions = "Squeeze."
        source.insert(custom)

        let data = try DataArchive.export(from: source)
        let destination = try Self.makeContext()
        let summary = try DataArchive.importArchive(try DataArchive.decode(data), into: destination)
        #expect(summary.customExercises == 1)

        let restored = try #require(try destination.fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(restored.slug == "custom-incline-hex-press")
        #expect(restored.name == "Incline Hex Press")
        #expect(restored.loadingMode == .timed)
        #expect(restored.primaryMuscles == [.chest])
        #expect(restored.equipment == [.dumbbell])
        #expect(restored.instructions == "Squeeze.")
    }

    @Test("Importing the same custom exercise twice adds it once")
    func backupImportIsIdempotent() throws {
        let source = try Self.makeContext()
        let custom = CustomExercise(name: "Zercher Carry")
        custom.primaryMuscles = [.core]
        source.insert(custom)
        let data = try DataArchive.export(from: source)

        let destination = try Self.makeContext()
        try DataArchive.importArchive(try DataArchive.decode(data), into: destination)
        let second = try DataArchive.importArchive(try DataArchive.decode(data), into: destination)

        #expect(second.customExercises == 0)
        #expect(try destination.fetch(FetchDescriptor<CustomExercise>()).count == 1)
    }

    @Test("A backup written before custom exercises existed still imports")
    func toleratesOlderBackups() throws {
        let context = try Self.makeContext()
        // customExercises is absent entirely, as in a file from before D-073.
        let json = """
        {"formatVersion":1,"exportedAt":"2026-09-01T10:00:00Z","programs":[],
         "unassignedWorkouts":[],"sessions":[],"exerciseFlags":[]}
        """
        let document = try DataArchive.decode(Data(json.utf8))
        #expect(document.customExercises == nil)
        let summary = try DataArchive.importArchive(document, into: context)
        #expect(summary.customExercises == 0)
    }
}
