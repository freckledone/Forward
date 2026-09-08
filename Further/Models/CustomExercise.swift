import Foundation
import SwiftData

/// A user-authored exercise (D-073), stored alongside the bundled catalog
/// rather than inside it.
///
/// The bundled catalog is read-only content shipped with the app (D-031), so
/// user-created entries cannot live there. This model mirrors `Exercise`'s
/// shape field-for-field and is projected into one through `asExercise`, which
/// lets every existing lookup, filter, search and tint path work unchanged.
///
/// Ids are prefixed `custom-` so a slug can never collide with a bundled one,
/// and so a `WorkoutExercise.exerciseId` is self-describing about where its
/// definition comes from.
///
/// CloudKit constraints (D-030): defaulted attributes, no unique attributes,
/// no relationships.
@Model
final class CustomExercise {
    var id: UUID = UUID()
    /// Stable slug used as `exerciseId` everywhere else in the app.
    var slug: String = ""
    var name: String = ""
    /// Stored joined by newline; `Exercise.aliases` wants an array, and
    /// CloudKit will not take one of a non-model type.
    var aliasesRaw: String = ""
    var loadingModeRaw: String = LoadingMode.weighted.rawValue
    var primaryMusclesRaw: String = ""
    var secondaryMusclesRaw: String = ""
    var equipmentRaw: String = ""
    var movementPatternRaw: String?
    var instructions: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String = "") {
        self.id = UUID()
        self.slug = Self.makeSlug(from: name)
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Typed accessors

    var aliases: [String] {
        get { Self.split(aliasesRaw).map { $0.lowercased() } }
        set { aliasesRaw = newValue.map { $0.lowercased() }.joined(separator: "\n") }
    }

    var loadingMode: LoadingMode {
        get { LoadingMode(rawValue: loadingModeRaw) ?? .weighted }
        set { loadingModeRaw = newValue.rawValue }
    }

    var primaryMuscles: [MuscleGroup] {
        get { Self.split(primaryMusclesRaw).compactMap(MuscleGroup.init(rawValue:)) }
        set { primaryMusclesRaw = newValue.map(\.rawValue).joined(separator: "\n") }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { Self.split(secondaryMusclesRaw).compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryMusclesRaw = newValue.map(\.rawValue).joined(separator: "\n") }
    }

    var equipment: [Equipment] {
        get { Self.split(equipmentRaw).compactMap(Equipment.init(rawValue:)) }
        set { equipmentRaw = newValue.map(\.rawValue).joined(separator: "\n") }
    }

    var movementPattern: MovementPattern? {
        get { movementPatternRaw.flatMap(MovementPattern.init(rawValue:)) }
        set { movementPatternRaw = newValue?.rawValue }
    }

    // MARK: - Projection

    /// The whole point of this type: hand the rest of the app an `Exercise`
    /// so nothing downstream needs to know the difference.
    var asExercise: Exercise {
        Exercise(
            id: slug,
            name: name,
            aliases: aliases,
            loadingMode: loadingMode,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            movementPattern: movementPattern,
            instructions: instructions
        )
    }

    // MARK: - Slugs

    /// `custom-incline-hex-press`. The prefix guarantees no collision with a
    /// bundled slug; the suffix keeps it readable in an exported backup.
    static func makeSlug(from name: String) -> String {
        let base = name
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { partial, character in
                if character == "-" && partial.hasSuffix("-") { return }
                partial.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return "custom-" + (base.isEmpty ? UUID().uuidString.lowercased() : base)
    }

    static func isCustom(_ exerciseId: String) -> Bool {
        exerciseId.hasPrefix("custom-")
    }

    private static func split(_ raw: String) -> [String] {
        raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }
}
