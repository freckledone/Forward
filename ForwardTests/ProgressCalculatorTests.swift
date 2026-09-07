import Testing
import SwiftData
import Foundation
@testable import Forward

@MainActor
@Suite("ProgressCalculator")
struct ProgressCalculatorTests {

    // MARK: - Fixture

    /// Fresh in-memory model container per test — no cross-contamination.
    static func makeContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// Build and insert a completed session containing one exercise with
    /// the given `sets`. Sets are all marked completed at time = startedAt.
    @discardableResult
    static func makeSession(
        in context: ModelContext,
        exerciseId: String,
        startedAt: Date,
        sets: [(weightKg: Double, reps: Int)]
    ) -> Session {
        let session = Session(
            startedAt: startedAt,
            workoutId: UUID(),
            workoutNameSnapshot: "Test Workout"
        )
        session.endedAt = startedAt.addingTimeInterval(60 * 45)
        context.insert(session)

        let se = SessionExercise(
            exerciseId: exerciseId,
            exerciseNameSnapshot: exerciseId,
            displayOrder: 0,
            targetSets: sets.count,
            targetRepsMin: sets.first?.reps ?? 0,
            targetRepsMax: sets.first?.reps ?? 0
        )
        se.session = session
        context.insert(se)

        for (i, values) in sets.enumerated() {
            let s = WorkSet(order: i, weightKg: values.weightKg, reps: values.reps, rir: nil)
            s.completedAt = startedAt
            s.sessionExercise = se
            context.insert(s)
        }

        return session
    }

    // MARK: - Empty case

    @Test("Empty history returns empty stats")
    func emptyHistory() throws {
        let context = try Self.makeContext()
        let stats = ProgressCalculator.stats(for: "bench", in: context)
        #expect(stats.isEmpty)
        #expect(stats.currentTopSet == nil)
        #expect(stats.repMaxes.isEmpty)
        #expect(stats.lastSessionSummary == nil)
    }

    // MARK: - Top set

    @Test("Top set = heaviest, ties by more reps")
    func topSetHeaviestWithTieBreak() throws {
        let context = try Self.makeContext()
        Self.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: Date(),
            sets: [
                (100, 5),  // ← tied weight, more reps than next
                (100, 3),
                (95, 8),
            ]
        )
        let stats = ProgressCalculator.stats(for: "bench", in: context)
        #expect(stats.currentTopSet?.weightKg == 100)
        #expect(stats.currentTopSet?.reps == 5)
    }

    // MARK: - Rep-max grid

    @Test("Rep-max grid picks heaviest per rep count across sessions")
    func repMaxAcrossSessions() throws {
        let context = try Self.makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        Self.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: base,
            sets: [(100, 5), (95, 8), (110, 3)]
        )
        Self.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: base.addingTimeInterval(60 * 60 * 24),
            sets: [(105, 5), (100, 8), (115, 1)]
        )

        let stats = ProgressCalculator.stats(for: "bench", in: context)
        #expect(stats.repMaxes[1] == 115)
        #expect(stats.repMaxes[3] == 110)
        #expect(stats.repMaxes[5] == 105)
        #expect(stats.repMaxes[8] == 100)
    }

    // MARK: - Chronological sessions

    @Test("Session trend points come back oldest-first")
    func trendChronological() throws {
        let context = try Self.makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // Insert out of order — expect stats to sort ascending.
        Self.makeSession(in: context, exerciseId: "bench", startedAt: base.addingTimeInterval(3600 * 24 * 5), sets: [(105, 5)])
        Self.makeSession(in: context, exerciseId: "bench", startedAt: base, sets: [(100, 5)])
        Self.makeSession(in: context, exerciseId: "bench", startedAt: base.addingTimeInterval(3600 * 24 * 2), sets: [(102.5, 5)])

        let stats = ProgressCalculator.stats(for: "bench", in: context)
        #expect(stats.sessions.count == 3)
        let weights = stats.sessions.map(\.topSetWeightKg)
        #expect(weights == [100, 102.5, 105])
    }

    // MARK: - PR detection

    @Test("PR is earned when set exceeds all-time weight at its rep count")
    func prBeatsHistoricalRepMax() throws {
        let context = try Self.makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // Historical: best 5-rep is 100 kg.
        Self.makeSession(in: context, exerciseId: "bench", startedAt: base, sets: [(100, 5)])

        // Today: 102.5 × 5 — new 5-rep PR.
        let today = Self.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: base.addingTimeInterval(3600 * 24 * 3),
            sets: [(102.5, 5), (100, 5), (95, 8)]
        )

        let prs = ProgressCalculator.prsAchieved(in: today, context: context)
        #expect(prs.count == 2)  // 5-rep PR and 8-rep PR (first ever at 8 reps)

        let bench5 = prs.first { $0.reps == 5 }
        #expect(bench5?.weightKg == 102.5)

        let bench8 = prs.first { $0.reps == 8 }
        #expect(bench8?.weightKg == 95)
    }

    @Test("PR ignores earlier sets in same session that don't beat history")
    func prIgnoresIntraSessionRegressions() throws {
        let context = try Self.makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // Historical 5-rep best = 105.
        Self.makeSession(in: context, exerciseId: "bench", startedAt: base, sets: [(105, 5)])

        // Today: 100 × 5 first (worse), 107.5 × 5 second (PR).
        let today = Self.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: base.addingTimeInterval(3600 * 24 * 3),
            sets: [(100, 5), (107.5, 5)]
        )

        let prs = ProgressCalculator.prsAchieved(in: today, context: context)
        #expect(prs.count == 1)
        #expect(prs.first?.weightKg == 107.5)
    }

    @Test("No PRs earned when nothing beats history")
    func noPRsWhenNothingBeats() throws {
        let context = try Self.makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        Self.makeSession(in: context, exerciseId: "bench", startedAt: base, sets: [(100, 5), (95, 8), (110, 3)])
        let today = Self.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: base.addingTimeInterval(3600 * 24 * 3),
            sets: [(95, 5), (90, 8), (100, 3)]
        )

        let prs = ProgressCalculator.prsAchieved(in: today, context: context)
        #expect(prs.isEmpty)
    }
}

// MARK: - Recent best (Active Workout "Last" pill)

@MainActor
@Suite("ProgressCalculator.recentBest")
struct RecentBestTests {

    typealias Fixture = ProgressCalculatorTests

    private static let day: TimeInterval = 60 * 60 * 24

    @Test("No history returns nil")
    func noHistory() throws {
        let context = try Fixture.makeContext()
        let best = ProgressCalculator.recentBest(
            for: "bench",
            targetReps: 6...8,
            excluding: nil,
            in: context
        )
        #expect(best == nil)
    }

    @Test("Prefers the heaviest set inside the target rep range")
    func heaviestInsideRange() throws {
        let context = try Fixture.makeContext()
        Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: Date().addingTimeInterval(-3 * Self.day),
            // 120 kg is heavier but sits outside 6...8 reps.
            sets: [(120, 3), (100, 8), (95, 7)]
        )

        let best = ProgressCalculator.recentBest(
            for: "bench",
            targetReps: 6...8,
            excluding: nil,
            in: context
        )
        #expect(best?.weightKg == 100)
        #expect(best?.reps == 8)
        #expect(best?.withinTarget == true)
    }

    @Test("Reaches back past a session with no in-range set")
    func skipsSessionsWithoutMatch() throws {
        let context = try Fixture.makeContext()
        let now = Date()
        Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: now.addingTimeInterval(-10 * Self.day),
            sets: [(90, 8)]
        )
        // Most recent session was a heavy triple day — nothing in 6...8.
        Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: now.addingTimeInterval(-2 * Self.day),
            sets: [(130, 3), (130, 2)]
        )

        let best = ProgressCalculator.recentBest(
            for: "bench",
            targetReps: 6...8,
            excluding: nil,
            in: context
        )
        #expect(best?.weightKg == 90)
        #expect(best?.reps == 8)
        #expect(best?.withinTarget == true)
    }

    @Test("Falls back to the latest top set when nothing ever hit the range")
    func fallsBackOutsideRange() throws {
        let context = try Fixture.makeContext()
        let now = Date()
        Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: now.addingTimeInterval(-9 * Self.day),
            sets: [(80, 12)]
        )
        Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: now.addingTimeInterval(-1 * Self.day),
            sets: [(130, 3), (125, 3)]
        )

        let best = ProgressCalculator.recentBest(
            for: "bench",
            targetReps: 6...8,
            excluding: nil,
            in: context
        )
        #expect(best?.weightKg == 130)
        #expect(best?.reps == 3)
        #expect(best?.withinTarget == false)
    }

    @Test("Excluded session is not its own reference")
    func excludesInProgressSession() throws {
        let context = try Fixture.makeContext()
        let now = Date()
        Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: now.addingTimeInterval(-7 * Self.day),
            sets: [(100, 8)]
        )
        let today = Fixture.makeSession(
            in: context,
            exerciseId: "bench",
            startedAt: now,
            sets: [(110, 8)]
        )

        let best = ProgressCalculator.recentBest(
            for: "bench",
            targetReps: 6...8,
            excluding: today.id,
            in: context
        )
        #expect(best?.weightKg == 100)
    }

    @Test("Other exercises never leak in")
    func isolatedByExercise() throws {
        let context = try Fixture.makeContext()
        Fixture.makeSession(
            in: context,
            exerciseId: "squat",
            startedAt: Date().addingTimeInterval(-Self.day),
            sets: [(200, 8)]
        )

        let best = ProgressCalculator.recentBest(
            for: "bench",
            targetReps: 6...8,
            excluding: nil,
            in: context
        )
        #expect(best == nil)
    }
}
