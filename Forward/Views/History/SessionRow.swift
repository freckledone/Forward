import SwiftUI

/// Compact History row for one completed session.
///
/// A calendar-style date chip anchors the row so the list scans vertically by
/// date, the way a log should. To its right: what the session was, and the two
/// facts that actually vary between runs of the same workout — how long it
/// took and when it started.
///
/// Exercise and set counts are deliberately absent: sessions are instantiated
/// from saved workouts, so those numbers read identically on every run and
/// distinguish nothing.
struct SessionRow: View {
    let session: Session

    private var workoutName: String {
        session.workoutNameSnapshot ?? "Workout"
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("j:mm")
        return f
    }()

    private var durationString: String {
        guard let ended = session.endedAt else { return "—" }
        let seconds = ended.timeIntervalSince(session.startedAt)
        let mins = max(1, Int(seconds / 60))
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        let rem = mins % 60
        return rem == 0 ? "\(hours) h" : "\(hours) h \(rem) min"
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(session.startedAt)
    }

    var body: some View {
        HStack(spacing: 14) {
            dateChip

            VStack(alignment: .leading, spacing: 3) {
                Text(workoutName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(durationString) · \(Self.timeFormatter.string(from: session.startedAt))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    /// Weekday over day-of-month. Today's chip is accent-tinted so the most
    /// recent session is findable without reading a word.
    private var dateChip: some View {
        VStack(spacing: 0) {
            Text(Self.weekdayFormatter.string(from: session.startedAt))
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)

            Text(Self.dayFormatter.string(from: session.startedAt))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.accentColor : Color.primary)
        }
        .frame(width: 46, height: 46)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    isToday
                        ? Color.accentColor.opacity(0.14)
                        : Color(uiColor: .tertiarySystemFill)
                )
        }
    }
}
