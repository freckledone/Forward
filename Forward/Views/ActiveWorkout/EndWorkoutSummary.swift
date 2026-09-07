import SwiftUI
import SwiftData

/// Post-session summary sheet (D-016).
///
/// Shows duration, sets completed, and — the calm celebration moment — any
/// PRs achieved during the session, plus an optional note field. Done
/// dismisses.
///
/// This is also where the session is mirrored to Apple Health (D-028). The
/// write happens here rather than in `SessionLifecycle.end` so it runs exactly
/// once, only for sessions the user actually finished, and only when they've
/// opted in.
struct EndWorkoutSummary: View {
    @Bindable var session: Session
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitWorkoutWriter.self) private var healthWriter

    @Query private var prefsList: [UserPreferences]
    private var displayUnit: DisplayUnit { prefsList.first?.unit ?? .kg }

    @State private var achievedPRs: [ProgressCalculator.AchievedPR] = []
    @State private var didFireHaptic = false

    private var durationString: String {
        guard let ended = session.endedAt else { return "—" }
        let seconds = ended.timeIntervalSince(session.startedAt)
        let mins = Int(seconds / 60)
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        let rem = mins % 60
        return "\(hours) h \(rem) min"
    }

    private var completedSetsCount: Int {
        let exercises = session.exercises ?? []
        return exercises.reduce(0) { acc, se in
            acc + (se.sets ?? []).filter { $0.completedAt != nil }.count
        }
    }

    private var totalSetsCount: Int {
        let exercises = session.exercises ?? []
        return exercises.reduce(0) { $0 + ($1.sets ?? []).count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statsRow
                    if !achievedPRs.isEmpty {
                        prsSection
                    }
                    noteSection
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Text("Done").fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            achievedPRs = ProgressCalculator.prsAchieved(in: session, context: modelContext)
            if !achievedPRs.isEmpty && !didFireHaptic {
                Haptics.personalRecordEarned()
                didFireHaptic = true
            }
            await mirrorToHealth()
        }
    }

    // MARK: - Apple Health (D-028)

    /// Mirrors the finished session to Health, if the user opted in.
    ///
    /// Deliberately silent about failures. The session is already saved, and
    /// interrupting a summary screen with an alert about a mirror the user
    /// can't act on from here would be noise. `healthKitWorkoutUUID` staying
    /// nil is the record that it didn't happen.
    private func mirrorToHealth() async {
        guard prefsList.first?.healthKitEnabled == true else { return }
        guard session.healthKitWorkoutUUID == nil else { return }

        // `healthKitEnabled` lives in the synced store, so it arrives from
        // other devices — but HealthKit authorization is per-device. Ask here
        // if this device hasn't been asked yet (D-028: request at first End
        // Workout, never at launch).
        if healthWriter.isUndecided {
            _ = try? await healthWriter.requestAuthorization()
        }

        session.healthKitWorkoutUUID = try? await healthWriter.write(session)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let program = session.programNameSnapshot {
                Text(program.uppercased())
                    .font(.footnote.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.accentColor)
            }
            Text(session.workoutNameSnapshot ?? "Workout")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text(session.startedAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: durationString, label: "Duration")
            statCard(value: "\(completedSetsCount)/\(totalSetsCount)", label: "Sets")
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    // MARK: - PRs

    private var prsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(achievedPRs.count == 1 ? "New personal record" : "New personal records")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }

            VStack(spacing: 8) {
                ForEach(achievedPRs) { pr in
                    prRow(pr)
                }
            }
        }
    }

    private func prRow(_ pr: ProgressCalculator.AchievedPR) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(pr.reps)-rep PR")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(UnitConversion.display(weightKg: pr.weightKg, unit: displayUnit))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(
                "Form cues, mood, notes for next time…",
                text: Binding(
                    get: { session.note ?? "" },
                    set: { session.note = $0.isEmpty ? nil : $0 }
                ),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3...6)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
    }
}
