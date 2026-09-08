import SwiftUI
import SwiftData

/// Full-catalog exercise browser (D-021 "See all exercises").
///
/// Differs from `ExercisePicker` (which returns a chosen Exercise via
/// callback for template editing). This one navigates to `ExerciseDetailView`
/// so the user can read details and toggle the star.
///
/// Uses `ExerciseFilterBar` for the muscle / equipment filters. Starred
/// exercises are pinned to a "Starred" section when they match the current
/// filter/query.
struct ExerciseBrowser: View {
    @Environment(ExerciseCatalog.self) private var catalog

    @Query private var flags: [ExerciseUserFlag]

    @State private var query: String = ""
    @State private var muscleFilter: MuscleGroup? = nil
    @State private var equipmentFilter: Equipment? = nil

    private var starredIds: Set<String> {
        Set(flags.filter(\.isKey).map(\.exerciseId))
    }

    private var results: [Exercise] {
        catalog.exercises(
            matching: query,
            muscle: muscleFilter,
            equipment: equipmentFilter
        )
    }

    private var starredResults: [Exercise] {
        results.filter { starredIds.contains($0.id) }
    }

    private var otherResults: [Exercise] {
        results.filter { !starredIds.contains($0.id) }
    }

    var body: some View {
        List {
            if !starredResults.isEmpty {
                Section("Starred") {
                    ForEach(starredResults) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            row(for: exercise, starred: true)
                        }
                    }
                }
            }
            if !otherResults.isEmpty {
                Section(starredResults.isEmpty ? "All exercises" : "Others") {
                    ForEach(otherResults) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            row(for: exercise, starred: false)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top, spacing: 0) {
            ExerciseFilterBar(muscle: $muscleFilter, equipment: $equipmentFilter)
                .background(.bar)
        }
        .overlay {
            if results.isEmpty {
                emptyResults
            }
        }
        .searchable(text: $query, prompt: "Search exercises")
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for exercise: Exercise, starred: Bool) -> some View {
        HStack(spacing: 12) {
            if starred {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.footnote)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if let primary = exercise.primaryMuscles.first {
                        Text(primary.displayName)
                    }
                    if let equipment = exercise.equipment.first {
                        Text("·").foregroundStyle(.tertiary)
                        Text(equipment.displayName)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyResults: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "magnifyingglass")
        } description: {
            Text("Try clearing filters or the search text.")
        }
    }
}
