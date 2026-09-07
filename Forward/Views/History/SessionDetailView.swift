import SwiftUI
import SwiftData

/// Full detail for one completed session (D-027).
///
/// Hero: date, the session duration as the headline number, and a personal-
/// record badge when the session earned any. Then one section per exercise,
/// each footed by its top set and the change since the last time that exercise
/// was trained — D-003 defines progress as more weight or more reps, so that
/// delta is the single most on-mission number this screen can show.
///
/// Set rows carry no status icon. In a *completed* session the overwhelming
/// majority of sets were logged, so a checkmark on every row is a column of
/// noise that marks the default case. Only the exceptions say anything —
/// skipped and never-logged sets render as dimmed text instead of showing
/// weight/rep numbers that were only ever a suggestion.
struct SessionDetailView: View {
    @Bindable var session: Session

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitWorkoutWriter.self) private var healthWriter

    @Query private var prefsList: [UserPreferences]
    private var displayUnit: DisplayUnit { prefsList.first?.unit ?? .kg }

    @State private var confirmDelete = false
    @State private var prCount = 0
    /// Keyed by `SessionExercise.id`. Raw numbers only — formatting happens in
    /// the view so a unit change doesn't need a recompute.
    @State private var progressions: [UUID: Progression] = [:]

    private struct Progression {
        let topWeightKg: Double
        let topReps: Int
        let previousWeightKg: Double?
        let previousReps: Int?
    }

    private var orderedExercises: [SessionExercise] {
        (session.exercises ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    private var durationString: String {
        guard let ended = session.endedAt else { return "—" }
        let seconds = ended.timeIntervalSince(session.startedAt)
        let mins = max(1, Int(seconds / 60))
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        let rem = mins % 60
        return rem == 0 ? "\(hours) h" : "\(hours) h \(rem) min"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("j:mm")
        return f
    }()

    var body: some View {
        List {
            heroSection
            if let note = session.note, !note.isEmpty {
                noteSection(note)
            }
            ForEach(orderedExercises) { se in
                exerciseSection(for: se)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(session.workoutNameSnapshot ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
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
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                delete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This session and its logged sets will be permanently removed.")
        }
        .task {
            loadProgressions()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startedAt, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Text(durationString)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(subtitleLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if prCount > 0 {
                    prBadge
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 14, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var subtitleLine: String {
        var parts = ["Started \(Self.timeFormatter.string(from: session.startedAt))"]
        if let program = session.programNameSnapshot, !program.isEmpty {
            parts.append(program)
        }
        return parts.joined(separator: " · ")
    }

    private var prBadge: some View {
        Label(
            prCount == 1 ? "1 personal record" : "\(prCount) personal records",
            systemImage: "trophy.fill"
        )
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(Color.accentColor.opacity(0.14))
        }
    }

    // MARK: - Note

    private func noteSection(_ note: String) -> some View {
        Section("Note") {
            Text(note)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Exercise sections

    private func exerciseSection(for se: SessionExercise) -> some View {
        let sets = (se.sets ?? []).sorted { $0.order < $1.order }

        return Section {
            ForEach(sets) { set in
                setRow(set)
            }
        } header: {
            // No set count: the rows are right there to be counted.
            Text(se.exerciseNameSnapshot)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
                .padding(.top, 4)
        } footer: {
            if let progression = progressions[se.id] {
                footer(for: progression)
            }
        }
    }

    /// "Top set 100 kg × 8 · ↑ 2.5 kg" — the exercise's best work this session,
    /// and how it compares to the last time it was trained.
    private func footer(for p: Progression) -> some View {
        HStack(spacing: 6) {
            Text("Top set \(weightString(p.topWeightKg)) × \(p.topReps)")
                .monospacedDigit()

            if let change = change(for: p) {
                Text("·")
                    .foregroundStyle(.tertiary)
                Label(change.text, systemImage: change.symbol)
                    .foregroundStyle(change.tint)
                    .monospacedDigit()
            }
        }
        .font(.footnote)
        .padding(.top, 2)
    }

    private struct Change {
        let text: String
        let symbol: String
        let tint: Color
    }

    /// Weight takes precedence over reps: adding load is the stronger signal,
    /// and at equal load more reps is the next one. Only when both match do we
    /// say the session held steady.
    private func change(for p: Progression) -> Change? {
        guard let prevWeight = p.previousWeightKg, let prevReps = p.previousReps else {
            return Change(text: "First time", symbol: "sparkles", tint: .secondary)
        }

        if p.topWeightKg != prevWeight {
            let delta = abs(p.topWeightKg - prevWeight)
            let up = p.topWeightKg > prevWeight
            return Change(
                text: weightString(delta),
                symbol: up ? "arrow.up" : "arrow.down",
                tint: up ? Color.accentColor : .secondary
            )
        }

        if p.topReps != prevReps {
            let delta = abs(p.topReps - prevReps)
            let up = p.topReps > prevReps
            return Change(
                text: delta == 1 ? "1 rep" : "\(delta) reps",
                symbol: up ? "arrow.up" : "arrow.down",
                tint: up ? Color.accentColor : .secondary
            )
        }

        return Change(text: "Matched last time", symbol: "equal", tint: .secondary)
    }

    private func setRow(_ set: WorkSet) -> some View {
        let logged = set.completedAt != nil

        return HStack(spacing: 12) {
            Text("\(set.order + 1)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 14, alignment: .leading)

            if logged {
                HStack(spacing: 5) {
                    Text(weightLabel(for: set))
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .monospacedDigit()
                    Text("×")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    Text("\(set.reps)")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .monospacedDigit()
                }
                .foregroundStyle(.primary)
            } else {
                // No numbers: an unlogged set's weight/reps are a leftover
                // suggestion, and printing them would read as a lift.
                Text(set.skipped ? "Skipped" : "Not logged")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if logged, let rir = set.rir {
                Text("RIR \(rir)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Formatting

    private func weightLabel(for set: WorkSet) -> String {
        if set.weightKg <= 0 { return "BW" }
        return UnitConversion.display(weightKg: set.weightKg, unit: displayUnit)
    }

    private func weightString(_ kg: Double) -> String {
        UnitConversion.display(weightKg: kg, unit: displayUnit)
    }

    // MARK: - Data

    private func loadProgressions() {
        prCount = ProgressCalculator.prsAchieved(in: session, context: modelContext).count

        var result: [UUID: Progression] = [:]
        for se in orderedExercises {
            let completed = (se.sets ?? []).filter { $0.completedAt != nil && !$0.skipped }
            guard let top = completed.max(by: { a, b in
                a.weightKg != b.weightKg ? a.weightKg < b.weightKg : a.reps < b.reps
            }) else { continue }

            let previous = ProgressCalculator.previousTopSet(
                for: se.exerciseId,
                before: session.startedAt,
                in: modelContext
            )
            result[se.id] = Progression(
                topWeightKg: top.weightKg,
                topReps: top.reps,
                previousWeightKg: previous?.weightKg,
                previousReps: previous?.reps
            )
        }
        progressions = result
    }

    // MARK: - Actions

    /// Deleting a session also removes its mirrored `HKWorkout`, so Health
    /// doesn't keep a workout Forward no longer believes in. Captured before
    /// the delete, because the model object is gone straight afterwards.
    private func delete() {
        let mirroredWorkout = session.healthKitWorkoutUUID
        modelContext.delete(session)
        dismiss()

        if let mirroredWorkout {
            Task { try? await healthWriter.deleteWorkout(uuid: mirroredWorkout) }
        }
    }
}
