import Foundation
import Observation

/// Loads and serves the bundled exercise database (D-031).
///
/// The JSON is loaded once at app launch and held in-memory as a slug-keyed
/// dictionary. Filtering by metadata (muscle group / equipment / loading
/// mode) happens in Swift, not via SwiftData `#Predicate`, because
/// `Exercise` is a value type, not a SwiftData model.
///
/// Search behavior implements the V1 scoring rules in
/// `docs/06-exercise-database-specification.md` §6.
@Observable
final class ExerciseCatalog {
    private(set) var all: [Exercise] = []
    private(set) var byId: [String: Exercise] = [:]

    init() {
        load()
    }

    // MARK: - Lookup

    func exercise(withId id: String) -> Exercise? { byId[id] }

    // MARK: - Combined search + filter

    /// Return all exercises matching `query` (optional forgiving search) and
    /// filtered by `muscle` / `equipment` (both optional; AND-combined).
    ///
    /// Empty query with no filters returns the full catalog in alphabetical
    /// order. Non-empty query applies V1 scoring per docs/06 §6.
    ///
    /// No arbitrary cap — callers use `.prefix()` if they need to bound
    /// results. `List` / `LazyVStack` handle the full 590+ exercises fine.
    func exercises(
        matching query: String = "",
        muscle: MuscleGroup? = nil,
        equipment: Equipment? = nil
    ) -> [Exercise] {
        let candidates: [Exercise]
        if muscle == nil && equipment == nil {
            candidates = all
        } else {
            candidates = all.filter { ex in
                if let m = muscle, !ex.primaryMuscles.contains(m) { return false }
                if let e = equipment, !ex.equipment.contains(e) { return false }
                return true
            }
        }

        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return candidates }

        struct Scored { let score: Int; let exercise: Exercise }

        let scored: [Scored] = candidates.compactMap { ex in
            var s = 0
            let name = ex.name.lowercased()
            if name.hasPrefix(q) {
                s += 10
            } else if name.contains(q) {
                s += 5
            }
            for alias in ex.aliases where alias.contains(q) {
                s += 3
            }
            let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            if words.contains(where: { $0.hasPrefix(q) }) {
                s += 1
            }
            return s > 0 ? Scored(score: s, exercise: ex) : nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.exercise.name.lowercased() < rhs.exercise.name.lowercased()
            }
            .map(\.exercise)
    }

    // MARK: - Load

    private func load() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            assertionFailure("exercises.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Exercise].self, from: data)
            let sorted = decoded.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            self.all = sorted
            self.byId = Dictionary(uniqueKeysWithValues: sorted.map { ($0.id, $0) })
        } catch {
            assertionFailure("Failed to decode exercises.json: \(error)")
        }
    }
}
