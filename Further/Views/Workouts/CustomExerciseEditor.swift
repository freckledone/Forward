import SwiftUI
import SwiftData

/// Create or edit a user-authored exercise (D-073).
///
/// The form mirrors the bundled JSON schema field-for-field — name, aliases,
/// loading mode, primary and secondary muscles, equipment, movement pattern,
/// instructions — so a custom entry is indistinguishable from a bundled one
/// everywhere downstream.
///
/// Text fields for the free-form parts, multi-select toggles for the enums.
/// Nothing here can produce a value the rest of the app can't read, which is
/// the whole reason the enums are pickers rather than text.
struct CustomExerciseEditor: View {
    /// Existing exercise to edit, or nil to create one.
    var existing: CustomExercise?
    var onSaved: ((CustomExercise) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseCatalog.self) private var catalog

    @State private var name = ""
    @State private var aliasText = ""
    @State private var loadingMode: LoadingMode = .weighted
    @State private var primaryMuscles: Set<MuscleGroup> = []
    @State private var secondaryMuscles: Set<MuscleGroup> = []
    @State private var equipment: Set<Equipment> = []
    @State private var movementPattern: MovementPattern?
    @State private var instructions = ""
    @State private var didLoad = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A primary muscle is required: it drives card tints, the Progress
    /// dashboard, and the muscle filter. An exercise without one would be
    /// invisible in all three.
    private var canSave: Bool {
        !trimmedName.isEmpty && !primaryMuscles.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                loadingSection
                musclesSection
                equipmentSection
                instructionsSection
            }
            .navigationTitle(existing == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
            TextField("Other names, comma separated", text: $aliasText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Name")
        } footer: {
            Text("Other names make search find this exercise. \"OHP\" finds an overhead press.")
        }
    }

    private var loadingSection: some View {
        Section {
            Picker("Measured in", selection: $loadingMode) {
                ForEach(LoadingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Measured in")
        } footer: {
            Text(loadingModeFooter)
        }
    }

    private var loadingModeFooter: String {
        switch loadingMode {
        case .weighted:   return "Logged as weight × reps."
        case .bodyweight: return "Logged as reps, with optional added weight."
        case .timed:      return "Logged as a hold in seconds, with optional added weight."
        }
    }

    private var musclesSection: some View {
        Section {
            NavigationLink {
                MuscleMultiSelect(title: "Primary muscles", selection: $primaryMuscles)
            } label: {
                selectionRow("Primary", primaryMuscles.map(\.displayName))
            }
            NavigationLink {
                MuscleMultiSelect(title: "Secondary muscles", selection: $secondaryMuscles)
            } label: {
                selectionRow("Secondary", secondaryMuscles.map(\.displayName))
            }
        } header: {
            Text("Muscles")
        } footer: {
            Text("At least one primary muscle is required — it sets the card colour and decides which filters find this exercise.")
        }
    }

    private var equipmentSection: some View {
        Section("Equipment & pattern") {
            NavigationLink {
                EquipmentMultiSelect(selection: $equipment)
            } label: {
                selectionRow("Equipment", equipment.map(\.displayName))
            }
            Picker("Movement pattern", selection: $movementPattern) {
                Text("None").tag(MovementPattern?.none)
                ForEach(MovementPattern.allCases, id: \.self) { pattern in
                    Text(pattern.rawValue.capitalized).tag(MovementPattern?.some(pattern))
                }
            }
        }
    }

    private var instructionsSection: some View {
        Section("Notes") {
            TextField("Setup, cues, anything you'd forget", text: $instructions, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private func selectionRow(_ label: String, _ values: [String]) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 12)
            Text(values.isEmpty ? "None" : values.joined(separator: ", "))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Load and save

    private func loadExisting() {
        guard !didLoad, let existing else { didLoad = true; return }
        didLoad = true
        name = existing.name
        aliasText = existing.aliases.joined(separator: ", ")
        loadingMode = existing.loadingMode
        primaryMuscles = Set(existing.primaryMuscles)
        secondaryMuscles = Set(existing.secondaryMuscles)
        equipment = Set(existing.equipment)
        movementPattern = existing.movementPattern
        instructions = existing.instructions ?? ""
    }

    private func save() {
        let subject = existing ?? CustomExercise(name: trimmedName)
        if existing == nil {
            modelContext.insert(subject)
        }

        subject.name = trimmedName
        // The slug is the id other records point at, so it is fixed at
        // creation. Renaming an exercise must not orphan the workouts and
        // logged sessions that reference it.
        if existing == nil {
            subject.slug = CustomExercise.makeSlug(from: trimmedName)
        }
        subject.aliases = aliasText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        subject.loadingMode = loadingMode
        // Ordered for stable display; Set has no order of its own.
        subject.primaryMuscles = MuscleGroup.allCases.filter(primaryMuscles.contains)
        subject.secondaryMuscles = MuscleGroup.allCases.filter(secondaryMuscles.contains)
        subject.equipment = Equipment.allCases.filter(equipment.contains)
        subject.movementPattern = movementPattern
        subject.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        subject.updatedAt = Date()

        catalog.refreshCustom(from: modelContext)
        onSaved?(subject)
        dismiss()
    }
}

// MARK: - Multi-selects

private struct MuscleMultiSelect: View {
    let title: String
    @Binding var selection: Set<MuscleGroup>

    var body: some View {
        List(MuscleGroup.allCases, id: \.self) { muscle in
            Button {
                toggle(muscle)
            } label: {
                HStack {
                    Circle()
                        .fill(MuscleTint.color(for: muscle))
                        .frame(width: 10, height: 10)
                    Text(muscle.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection.contains(muscle) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection.contains(muscle) ? [.isSelected] : [])
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ muscle: MuscleGroup) {
        if selection.contains(muscle) { selection.remove(muscle) } else { selection.insert(muscle) }
    }
}

private struct EquipmentMultiSelect: View {
    @Binding var selection: Set<Equipment>

    var body: some View {
        List(Equipment.allCases, id: \.self) { item in
            Button {
                if selection.contains(item) { selection.remove(item) } else { selection.insert(item) }
            } label: {
                HStack {
                    Text(item.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selection.contains(item) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection.contains(item) ? [.isSelected] : [])
        }
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
