import SwiftUI
import SwiftData
import Charts

/// Progress dashboard card for a starred exercise (D-021, D-022).
///
/// Header: exercise name + primary muscle chip.
/// Hero: current top set (44pt rounded weight × reps in `.title3.rounded`).
/// Trend: 12-week mini chart (no axes / no marks — visual only).
/// Footer: last-session summary.
struct ProgressCard: View {
    /// A literal point size ignores Dynamic Type entirely. `@ScaledMetric`
    /// keeps the intended size at the default setting and scales from there.
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 44

    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext

    @Query private var prefsList: [UserPreferences]
    private var displayUnit: DisplayUnit { prefsList.first?.unit ?? .kg }

    @State private var stats: ProgressStats?

    private var primaryMuscle: MuscleGroup? { exercise.primaryMuscles.first }

    /// Trend limited to the last 12 weeks per D-022.
    private var trendPoints: [ProgressStats.SessionPoint] {
        guard let stats else { return [] }
        let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: Date())
            ?? Date().addingTimeInterval(-12 * 7 * 24 * 3600)
        return stats.sessions.filter { $0.sessionDate >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            heroNumber
            if !trendPoints.isEmpty {
                miniChart
            }
            if let summary = stats?.lastSessionSummary {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(tint: primaryMuscle)
        .task {
            stats = ProgressCalculator.stats(for: exercise.id, in: modelContext)
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(exercise.name)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let muscle = primaryMuscle {
                Text(muscle.rawValue.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background { Capsule().fill(Color(uiColor: .tertiarySystemFill)) }
            }
        }
    }

    // MARK: - Hero number

    private var heroNumber: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            if let top = stats?.currentTopSet {
                Text(UnitConversion.display(weightKg: top.weightKg, unit: displayUnit))
                    .font(.system(size: heroSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("× \(top.reps)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.system(size: heroSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("no data yet")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Mini chart

    private var miniChart: some View {
        Chart(trendPoints) { point in
            LineMark(
                x: .value("Date", point.sessionDate),
                y: .value("Weight", displayWeight(point.topSetWeightKg))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            AreaMark(
                x: .value("Date", point.sessionDate),
                y: .value("Weight", displayWeight(point.topSetWeightKg))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.frame(height: 44)
        }
    }

    private func displayWeight(_ kg: Double) -> Double {
        switch displayUnit {
        case .kg: return kg
        case .lb: return UnitConversion.lb(fromKg: kg)
        }
    }
}
