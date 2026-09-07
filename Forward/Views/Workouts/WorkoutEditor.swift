import SwiftUI
import SwiftData

/// Form-style editor for creating/editing a Workout (formerly TemplateEditor).
///
/// - Name field
/// - Exercises list (reorderable, deletable via swipe)
/// - "Add Exercise" button presents `ExercisePicker` as a sheet
/// - Persist-on-change (D-029); no explicit Save.
struct WorkoutEditor: View {
    @Bindable var workout: Workout

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseCatalog.self) private var catalog

    @State private var pickerPresented = false
    @State private var confirmDelete = false

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

            Section {
                if orderedExercises.isEmpty {
                    Text("No exercises yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(orderedExercises) { we in
                        WorkoutExerciseRow(workoutExercise: we)
                    }
                    .onDelete { offsets in
                        deleteExercises(at: offsets)
                    }
                    .onMove { source, destination in
                        moveExercises(from: source, to: destination)
                    }
                }

                Button {
                    pickerPresented = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Exercises")
            } footer: {
                if !orderedExercises.isEmpty {
                    Text("Tap a row to edit sets and rep range. Swipe to remove.")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(workout.name.isEmpty ? "New Workout" : workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !orderedExercises.isEmpty {
                        EditButton()
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $pickerPresented) {
            ExercisePicker { exercise in
                addExercise(exercise)
            }
        }
        .confirmationDialog(
            "Delete \"\(workout.name.isEmpty ? "this workout" : workout.name)\"?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the workout and its exercises. Your logged sessions from this workout will remain in History.")
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
