import SwiftUI
import SwiftData

/// Form-style editor for creating/editing a Workout (formerly TemplateEditor).
///
/// - Name field and tint picker
/// - Exercises list: reorderable, swipe for Swap / Delete
/// - "Add Exercise" presents `ExercisePicker` as a sheet
/// - Persist-on-change (D-029); no explicit Save.
struct WorkoutEditor: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseCatalog.self) private var catalog

    @State private var picker: PickerMode?
    @State private var confirmDelete = false

    /// One sheet, two jobs. Two `.sheet` modifiers on the same view is a
    /// coin-flip over which one wins, so the mode is modelled instead.
    private enum PickerMode: Identifiable {
        case add
        case swap(WorkoutExercise)

        var id: String {
            switch self {
            case .add: return "add"
            case .swap(let we): return "swap-\(we.id.uuidString)"
            }
        }
    }

    private var orderedExercises: [WorkoutExercise] {
        (workout.exercises ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Workout name", text: $workout.name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: workout.name) { _, _ in workout.updatedAt = Date() }
            }

            Section {
                WorkoutTintPicker(
                    selection: Binding(
                        get: { workout.tintOverride },
                        set: { newValue in
                            workout.tintOverride = newValue
                            workout.updatedAt = Date()
                        }
                    )
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Tint")
            } footer: {
                Text("Choose a color for this workout's card, or leave as Auto to inherit from the first exercise's primary muscle.")
                    .font(.footnote)
            }

            exercisesSection
            deleteSection
        }
        .navigationTitle(workout.name.isEmpty ? "New Workout" : workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !orderedExercises.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .sheet(item: $picker) { mode in
            ExercisePicker { exercise in
                switch mode {
                case .add: addExercise(exercise)
                case .swap(let we): swap(we, to: exercise)
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(workout.name.isEmpty ? "this workout" : workout.name)\"?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the workout and its exercises. Sessions you already logged from it stay in History.")
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        Section {
            if orderedExercises.isEmpty {
                Text("No exercises yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(orderedExercises) { we in
                    WorkoutExerciseRow(workoutExercise: we)
                        // Full swipe is off deliberately: with a destructive
                        // action in the tray, a fast flick would delete an
                        // exercise the user meant to swap.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(we)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                picker = .swap(we)
                            } label: {
                                Label("Swap", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .tint(Color.accentColor)
                        }
                }
                .onDelete { offsets in
                    deleteExercises(at: offsets)
                }
                .onMove { source, destination in
                    moveExercises(from: source, to: destination)
                }
            }

            Button {
                picker = .add
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Exercises")
        } footer: {
            if !orderedExercises.isEmpty {
                Text("Tap a row to edit sets and rep range. Swipe left to swap the exercise or remove it.")
                    .font(.footnote)
            }
        }
    }

    /// Destructive actions belong at the bottom of the screen they act on —
    /// the pattern Contacts and Calendar use — not hidden in an overflow menu.
    /// It is also more predictable: a confirmation raised from inside a menu
    /// has to wait for that menu to dismiss first, which is what made this one
    /// appear detached from the control that triggered it.
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Text("Delete Workout")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Mutations

    private func addExercise(_ exercise: Exercise) {
        let nextOrder = (orderedExercises.map(\.displayOrder).max() ?? -1) + 1
        let we = WorkoutExercise(
            exerciseId: exercise.id,
            displayOrder: nextOrder,
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 8
        )
        we.workout = workout
        modelContext.insert(we)
        if workout.exercises == nil {
            workout.exercises = [we]
        } else {
            workout.exercises?.append(we)
        }
        workout.updatedAt = Date()
    }

    /// Point the slot at a different exercise, keeping its position, set count
    /// and rep range. Nothing is reset — unlike a mid-session swap (D-053),
    /// a workout holds no logged data to invalidate.
    private func swap(_ we: WorkoutExercise, to exercise: Exercise) {
        guard we.exerciseId != exercise.id else { return }
        we.exerciseId = exercise.id
        workout.updatedAt = Date()
    }

    private func delete(_ we: WorkoutExercise) {
        modelContext.delete(we)
        workout.updatedAt = Date()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let list = orderedExercises
        for i in offsets {
            modelContext.delete(list[i])
        }
        workout.updatedAt = Date()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var reordered = orderedExercises
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, we) in reordered.enumerated() {
            we.displayOrder = index
        }
        workout.updatedAt = Date()
    }

    private func deleteWorkout() {
        modelContext.delete(workout)
        dismiss()
    }
}
