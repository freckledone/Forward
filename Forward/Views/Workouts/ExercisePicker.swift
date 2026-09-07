import SwiftUI

/// Sheet-presented exercise chooser backed by `ExerciseCatalog`.
///
/// Presents a searchable + filterable list. Tapping a row invokes
/// `onPick(exercise)` and dismisses. Uses `ExerciseFilterBar` for the
/// muscle / equipment filters.
struct ExercisePicker: View {
    let onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseCatalog.self) private var catalog

    @State private var query: String = ""
    @State private var muscleFilter: MuscleGroup? = nil
    @State private var equipmentFilter: Equipment? = nil

    private var results: [Exercise] {
        catalog.exercises(
            matching: query,
            muscle: muscleFilter,
            equipment: equipmentFilter
        )
    }

    var body: some View {
        NavigationStack {
            List(results) { exercise in
                Button {
                    onPick(exercise)
                    dismiss()
                } label: {
                    row(for: exercise)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
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
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func row(for exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 4)
    }

    private var emptyResults: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "magnifyingglass")
        } description: {
            Text("Try clearing filters or the search text.")
        }
    }
}
