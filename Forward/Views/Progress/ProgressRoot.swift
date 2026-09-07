import SwiftUI
import SwiftData

/// Progress tab (D-020, D-021). Dashboard of key-lift cards, plus a link at
/// the bottom to browse the full exercise catalog.
struct ProgressRoot: View {
    @Environment(ExerciseCatalog.self) private var catalog

    @Query(filter: #Predicate<ExerciseUserFlag> { $0.isKey })
    private var keyFlags: [ExerciseUserFlag]

    private var keyExercises: [Exercise] {
        keyFlags
            .compactMap { catalog.exercise(withId: $0.exerciseId) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if keyExercises.isEmpty {
                    emptyState
                } else {
                    dashboard
                }
            }
            .navigationTitle("Progress")
        }
    }

    // MARK: - Empty state

    /// `ContentUnavailableView` centers itself and has an `actions` slot. The
    /// old version wrapped it in a ScrollView and faked centering with a 320pt
    /// minimum height, which breaks down at large Dynamic Type. This also
    /// matches the empty state on Workouts.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No key lifts starred", systemImage: "star")
        } description: {
            Text("Star an exercise to see progress here.")
        } actions: {
            NavigationLink {
                ExerciseBrowser()
            } label: {
                Text("Browse Exercises")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(keyExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ProgressCard(exercise: exercise)
                            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    ExerciseBrowser()
                } label: {
                    HStack {
                        Text("See all exercises")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(16)
        }
    }
}
