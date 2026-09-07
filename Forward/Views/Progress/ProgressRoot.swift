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

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                ContentUnavailableView {
                    Label("No key lifts starred", systemImage: "star")
                } description: {
                    Text("Star an exercise to see progress here.")
                }
                .frame(minHeight: 320)

                NavigationLink {
                    ExerciseBrowser()
                } label: {
                    Label("Browse Exercises", systemImage: "list.bullet.rectangle")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
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
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
