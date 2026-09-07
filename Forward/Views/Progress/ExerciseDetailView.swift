import SwiftUI
import SwiftData
import Charts

/// Combined exercise info + progress + star toggle (D-020, D-022, D-023).
///
/// Always shown: metadata (muscles, equipment, movement pattern), instructions.
/// If the user has completed sets of this exercise: adds rep-max grid, trend
/// chart, and session list.
struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query private var flags: [ExerciseUserFlag]
    @Query private var prefsList: [UserPreferences]

    @State private var stats: ProgressStats?

    private var displayUnit: DisplayUnit { prefsList.first?.unit ?? .kg }

    private var flag: ExerciseUserFlag? {
        flags.first { $0.exerciseId == exercise.id }
    }

    private var isKey: Bool { flag?.isKey ?? false }

    private var primaryMuscle: MuscleGroup? { exercise.primaryMuscles.first }

    var body: some View {
        List {
            heroSection
            metadataSection
            if let stats, !stats.isEmpty {
                progressStatsSection(stats)
                trendChartSection(stats)
                repMaxSection(stats)
            }
            if let instructions = exercise.instructions, !instructions.isEmpty {
                instructionsSection(instructions)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleStar()
                } label: {
                    Image(systemName: isKey ? "star.fill" : "star")
                        .foregroundStyle(isKey ? Color.accentColor : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(isKey ? "Unstar exercise" : "Star exercise")
            }
        }
        .task {
            stats = ProgressCalculator.stats(for: exercise.id, in: modelContext)
        }
    }

    // MARK: - Hero (name area)

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.name)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                musclePillsRow
            }
            .padding(.vertical, 4)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(MuscleTint.cardGradient(for: primaryMuscle, colorScheme: colorScheme))
                    }
            )
        }
    }

    private var musclePillsRow: some View {
        HStack(spacing: 6) {
            ForEach(exercise.primaryMuscles, id: \.self) { muscle in
                pill(text: muscle.displayName, prominent: true)
            }
            ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                pill(text: muscle.displayName, prominent: false)
            }
        }
    }

    private func pill(text: String, prominent: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(prominent ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(Color(uiColor: prominent ? .tertiarySystemFill : .quaternarySystemFill))
            }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        Section("Details") {
            metaRow(label: "Equipment", value: exercise.equipment.map(\.displayName).joined(separator: ", "))
            metaRow(label: "Loading", value: exercise.loadingMode.rawValue.capitalized)
            if let pattern = exercise.movementPattern {
                metaRow(label: "Movement", value: pattern.rawValue.capitalized)
            }
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Progress: current top set

    private func progressStatsSection(_ stats: ProgressStats) -> some View {
        Section {
            if let current = stats.currentTopSet {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current top set")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(UnitConversion.display(weightKg: current.weightKg, unit: displayUnit))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("× \(current.reps)")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)
            }
            if let summary = stats.lastSessionSummary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Progress: trend chart

    private func trendChartSection(_ stats: ProgressStats) -> some View {
        Section("Top-set trend") {
            Chart(stats.sessions) { point in
                LineMark(
                    x: .value("Date", point.sessionDate),
                    y: .value("Weight", pointWeight(point.topSetWeightKg))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)

                AreaMark(
                    x: .value("Date", point.sessionDate),
                    y: .value("Weight", pointWeight(point.topSetWeightKg))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                PointMark(
                    x: .value("Date", point.sessionDate),
                    y: .value("Weight", pointWeight(point.topSetWeightKg))
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(30)
            }
            .frame(height: 180)
            .padding(.vertical, 4)
        }
    }

    private func pointWeight(_ kg: Double) -> Double {
        switch displayUnit {
        case .kg: return kg
        case .lb: return UnitConversion.lb(fromKg: kg)
        }
    }

    // MARK: - Progress: rep-max grid

    private func repMaxSection(_ stats: ProgressStats) -> some View {
        Section("Rep-max PRs") {
            ForEach(ProgressCalculator.repMaxTargets, id: \.self) { reps in
                HStack {
                    Text("\(reps)-rep max")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let kg = stats.repMaxes[reps] {
                        Text(UnitConversion.display(weightKg: kg, unit: displayUnit))
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    } else {
                        Text("—")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Instructions

    private func instructionsSection(_ text: String) -> some View {
        Section("Instructions") {
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Star action

    private func toggleStar() {
        Haptics.starToggled()
        if let existing = flag {
            existing.isKey.toggle()
            existing.updatedAt = Date()
        } else {
            let new = ExerciseUserFlag(exerciseId: exercise.id, isKey: true)
            modelContext.insert(new)
        }
    }
}
