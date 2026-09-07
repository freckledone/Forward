import SwiftUI
import SwiftData

/// History tab (D-027). Sessions grouped by month; tap a row to open detail.
struct HistoryRoot: View {
    @Query(
        filter: #Predicate<Session> { $0.endedAt != nil },
        sort: \Session.startedAt,
        order: .reverse
    )
    private var completedSessions: [Session]

    private static let monthHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()

    /// Group sessions by (year, month) — most-recent month first, sessions
    /// within a month sorted most-recent-first.
    private var groupedByMonth: [(month: Date, sessions: [Session])] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: completedSessions) { session -> Date in
            let comps = calendar.dateComponents([.year, .month], from: session.startedAt)
            return calendar.date(from: comps) ?? session.startedAt
        }
        return buckets
            .map { key, values in
                (month: key, sessions: values.sorted { $0.startedAt > $1.startedAt })
            }
            .sorted { $0.month > $1.month }
    }

    var body: some View {
        NavigationStack {
            Group {
                if completedSessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No workouts yet", systemImage: "clock.arrow.circlepath")
        } description: {
            Text("Completed workouts appear here.")
        }
    }

    private var sessionList: some View {
        List {
            ForEach(groupedByMonth, id: \.month) { group in
                Section {
                    ForEach(group.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                } header: {
                    Text(Self.monthHeaderFormatter.string(from: group.month))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                        .padding(.top, 8)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
