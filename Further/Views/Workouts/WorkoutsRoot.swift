import SwiftUI
import SwiftData

/// Home / Workouts tab (D-018, D-047).
///
/// - Resume banner at top if an in-progress session exists (D-029)
/// - One Section per Program; each Section's rows are that Program's Workouts
/// - + menu offers "New Workout" (default) and "New Program"
/// - Empty state when nothing exists (D-017)
struct WorkoutsRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ExerciseCatalog.self) private var catalog
    @Environment(WorkoutActivityController.self) private var activityController

    // Programs ordered by user-defined displayOrder.
    @Query(sort: \Program.displayOrder) private var programs: [Program]

    // In-progress sessions (endedAt == nil). Newest first (D-029).
    @Query(
        filter: #Predicate<Session> { $0.endedAt == nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var inProgress: [Session]

    // Push-nav target when we've created a workout and want to open the editor.
    @State private var editingWorkout: Workout?

    // Full-screen session cover — either a resumed or freshly-started Session.
    @State private var activeSession: Session?
    @State private var finishedSession: Session?

    // Program rename sheet target.
    @State private var renamingProgram: Program?

    // Settings sheet.
    @State private var showingSettings = false

    private let engine: SuggestionEngine = LastSessionSuggestionEngine()

    private var hasAnyWorkout: Bool {
        programs.contains { !(($0.workouts ?? []).isEmpty) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnyWorkout && inProgress.isEmpty {
                    emptyState
                } else {
                    contentList
                }
            }
            .navigationTitle("Workouts")
            .toolbar { toolbarContent }
            .navigationDestination(item: $editingWorkout) { workout in
                WorkoutEditor(workout: workout)
            }
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(
                    session: session,
                    onFinish: { finished in
                        activeSession = nil
                        finishedSession = finished
                    },
                    onDiscard: {
                        // Discarding is the other way out of a workout; the
                        // card has to go with it.
                        activityController.end()
                        SessionLifecycle.discard(session, context: modelContext)
                        activeSession = nil
                    }
                )
            }
            .sheet(item: $finishedSession) { session in
                EndWorkoutSummary(session: session) {
                    finishedSession = nil
                }
            }
            .sheet(item: $renamingProgram) { program in
                ProgramRenameSheet(program: program)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Empty state (D-017)

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No workouts yet", systemImage: "dumbbell")
        } description: {
            Text("Create your first workout to start logging. Workouts belong to a program — we'll create one for you automatically.")
        } actions: {
            Button {
                createWorkout()
            } label: {
                Text("Create Workout")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Content list

    private var contentList: some View {
        List {
            if let inProgressSession = inProgress.first {
                Section {
                    ResumeBanner(session: inProgressSession) {
                        activeSession = inProgressSession
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(programs) { program in
                Section {
                    let workouts = (program.workouts ?? []).sorted { $0.displayOrder < $1.displayOrder }
                    ForEach(workouts) { workout in
                        // Programmatic push rather than a NavigationLink: a
                        // link row draws a disclosure chevron, and the card
                        // already says "tap me" on its own.
                        WorkoutCard(
                            workout: workout,
                            onOpen: { editingWorkout = workout },
                            onStart: { startWorkout(from: workout) }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        moveWorkouts(from: program, from: source, to: destination)
                    }
                } header: {
                    programHeader(for: program)
                }
            }
        }
        .listStyle(.plain)
    }

    private func programHeader(for program: Program) -> some View {
        let workoutCount = (program.workouts ?? []).count
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name.isEmpty ? "Untitled Program" : program.name)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                Text(workoutCount == 1 ? "1 workout" : "\(workoutCount) workouts")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .textCase(nil)

            Spacer(minLength: 4)

            Menu {
                Button {
                    createWorkout(in: program)
                } label: {
                    Label("Add Workout", systemImage: "plus")
                }
                Button {
                    renamingProgram = program
                } label: {
                    Label("Rename Program", systemImage: "pencil")
                }
                if programs.count > 1 {
                    Button(role: .destructive) {
                        deleteProgram(program)
                    } label: {
                        Label("Delete Program", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    createWorkout()
                } label: {
                    Label("New Workout", systemImage: "dumbbell.fill")
                }
                Button {
                    createProgram()
                } label: {
                    Label("New Program", systemImage: "folder.fill")
                }
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add")
        }
        if hasAnyWorkout {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    // MARK: - Create actions

    /// Create a workout in the given program, or the default program (creating
    /// "My Program" if none exists).
    private func createWorkout(in program: Program? = nil) {
        let target: Program
        if let program {
            target = program
        } else if let first = programs.first {
            target = first
        } else {
            target = createDefaultProgram()
        }

        let existingWorkouts = (target.workouts ?? [])
        let nextOrder = (existingWorkouts.map(\.displayOrder).max() ?? -1) + 1
        let workout = Workout(name: "New Workout", displayOrder: nextOrder)
        workout.program = target
        modelContext.insert(workout)
        target.workouts = (target.workouts ?? []) + [workout]
        target.updatedAt = Date()
        editingWorkout = workout
    }

    private func createProgram() {
        let nextOrder = (programs.map(\.displayOrder).max() ?? -1) + 1
        let program = Program(name: "New Program", displayOrder: nextOrder)
        modelContext.insert(program)
        renamingProgram = program
    }

    @discardableResult
    private func createDefaultProgram() -> Program {
        let program = Program(name: "My Program", displayOrder: 0)
        modelContext.insert(program)
        return program
    }

    // MARK: - Mutations

    private func startWorkout(from workout: Workout) {
        // If there's already an in-progress session, jump into it rather
        // than creating a second one.
        if let existing = inProgress.first {
            activeSession = existing
            return
        }
        let session = SessionLifecycle.start(
            from: workout,
            catalog: catalog,
            engine: engine,
            context: modelContext
        )
        activeSession = session
    }

    private func moveWorkouts(from program: Program, from source: IndexSet, to destination: Int) {
        var reordered = (program.workouts ?? []).sorted { $0.displayOrder < $1.displayOrder }
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, workout) in reordered.enumerated() {
            workout.displayOrder = index
        }
        program.updatedAt = Date()
    }

    private func deleteProgram(_ program: Program) {
        modelContext.delete(program)
    }
}

/// Simple rename sheet for a Program.
struct ProgramRenameSheet: View {
    @Bindable var program: Program
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Program name") {
                    TextField("Name", text: $program.name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Rename Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        program.updatedAt = Date()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
