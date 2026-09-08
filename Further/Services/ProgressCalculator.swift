import Foundation
import SwiftData

/// Per-exercise progress statistics for the Progress dashboard and detail
/// view. All numbers are computed on demand from `WorkSet` records — no cache
/// in V1 (05 §3.4 rule 7). If profiling shows this is slow at ~1000+ sets
/// per exercise, we add a cache.
struct ProgressStats {
    struct SessionPoint: Identifiable, Hashable {
        let id: UUID
        let sessionDate: Date
        let topSetWeightKg: Double
        let topSetReps: Int
    }

    /// Time-ordered (oldest first) session-level top sets, for the chart.
    let sessions: [SessionPoint]

    /// Most recent session's top set — the card headline.
    let currentTopSet: (weightKg: Double, reps: Int)?

    /// Per-rep-count personal records. D-023: heaviest weight ever lifted
    /// for exactly N reps. Only entries with actual history included.
    let repMaxes: [Int: Double]

    /// Human summary of the last session's top-set weights, e.g.
    /// "3 days ago: 100 kg × 5, 5, 4".
    let lastSessionSummary: String?

    var isEmpty: Bool { sessions.isEmpty }
}

enum ProgressCalculator {
    /// Rep counts included in the rep-max grid (D-022).
    static let repMaxTargets: [Int] = [1, 3, 5, 8, 10]

    /// Compute stats for a single exercise by aggregating across all past
    /// completed sessions.
    static func stats(
        for exerciseId: String,
        in context: ModelContext
    ) -> ProgressStats {
        // Fetch every SessionExercise for this exerciseId across all sessions.
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { $0.exerciseId == exerciseId }
        )
        let allInstances: [SessionExercise]
        do {
            allInstances = try context.fetch(descriptor)
        } catch {
            return empty()
        }

        // Build per-session top-set points from completed, non-skipped sets.
        var points: [ProgressStats.SessionPoint] = []
        for se in allInstances {
            guard let session = se.session, session.endedAt != nil else { continue }
            let completed = (se.sets ?? []).filter { $0.completedAt != nil && !$0.skipped }
            guard let top = completed.max(by: setOrder) else { continue }
            points.append(
                ProgressStats.SessionPoint(
                    id: se.id,
                    sessionDate: session.startedAt,
                    topSetWeightKg: top.weightKg,
                    topSetReps: top.reps
                )
            )
        }
        points.sort { $0.sessionDate < $1.sessionDate }

        // Current top set = most-recent session's top set.
        let currentTop: (Double, Int)?
        if let latest = points.last {
            currentTop = (latest.topSetWeightKg, latest.topSetReps)
        } else {
            currentTop = nil
        }

        // Per-rep-count PRs across every completed non-skipped set ever.
        var repMaxes: [Int: Double] = [:]
        for se in allInstances {
            let completed = (se.sets ?? []).filter {
                // Timed sets have no rep count, so every one of them would
                // collide on key 0 and report a nonsense "0-rep PR".
                $0.completedAt != nil && !$0.skipped && $0.durationSeconds == nil
            }
            for s in completed {
                let existing = repMaxes[s.reps] ?? 0
                if s.weightKg > existing {
                    repMaxes[s.reps] = s.weightKg
                }
            }
        }

        // Last-session summary line.
        let summary = makeLastSessionSummary(from: allInstances)

        return ProgressStats(
            sessions: points,
            currentTopSet: currentTop.map { ($0.0, $0.1) },
            repMaxes: repMaxes,
            lastSessionSummary: summary
        )
    }

    // MARK: - Helpers

    /// "Top set" is heaviest weight, ties broken by higher rep count — except
    /// for timed sets, where the best set is the longest hold (D-072).
    private static func setOrder(_ a: WorkSet, _ b: WorkSet) -> Bool {
        if let da = a.durationSeconds, let db = b.durationSeconds {
            if da != db { return da < db }
            return a.weightKg < b.weightKg
        }
        if a.weightKg != b.weightKg { return a.weightKg < b.weightKg }
        return a.reps < b.reps
    }

    private static func makeLastSessionSummary(
        from instances: [SessionExercise]
    ) -> String? {
        // Find the most recent completed SessionExercise.
        let sorted = instances.compactMap { se -> (Date, SessionExercise)? in
            guard let s = se.session, let ended = s.endedAt else { return nil }
            _ = ended
            return (s.startedAt, se)
        }.sorted { $0.0 > $1.0 }

        guard let (date, se) = sorted.first else { return nil }

        let completed = (se.sets ?? [])
            .filter { $0.completedAt != nil && !$0.skipped }
            .sorted { $0.order < $1.order }
        guard !completed.isEmpty else { return nil }

        let dateStr = relativeString(for: date)
        // "100 kg × 5, 5, 4" — top-set weight, then reps per set.
        let topWeight = completed.map(\.weightKg).max() ?? 0
        let repsList = completed.map { String($0.reps) }.joined(separator: ", ")

        if topWeight <= 0 {
            return "\(dateStr): × \(repsList)"
        }
        // Note: we don't have DisplayUnit here — leave as kg; view layer can
        // reformat if it needs to.
        let weightStr = String(format: "%g kg", topWeight)
        return "\(dateStr): \(weightStr) × \(repsList)"
    }

    private static func relativeString(for date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    private static func empty() -> ProgressStats {
        ProgressStats(
            sessions: [],
            currentTopSet: nil,
            repMaxes: [:],
            lastSessionSummary: nil
        )
    }

    // MARK: - Recent best (Active Workout reference)

    /// The heaviest set from a past session, used as the "what did I do last
    /// time" reference shown next to the target during a workout.
    struct RecentBest: Hashable {
        let weightKg: Double
        let reps: Int
        let date: Date
        /// True when this set's rep count falls inside the exercise's target
        /// rep range — i.e. it's a like-for-like comparison, not just the last
        /// thing that happened to be logged.
        let withinTarget: Bool
    }

    /// Heaviest past set for `exerciseId`, preferring sets whose rep count sits
    /// inside `targetReps`.
    ///
    /// Walks completed sessions newest-first and returns the top set from the
    /// most recent session that contains a rep-count match. If no session ever
    /// hit the target range, falls back to the most recent session's top set
    /// with `withinTarget == false`, so the user still sees *something*.
    ///
    /// `excluding` drops the in-progress session so a set logged moments ago
    /// doesn't become its own reference.
    static func recentBest(
        for exerciseId: String,
        targetReps: ClosedRange<Int>?,
        excluding sessionId: UUID?,
        in context: ModelContext
    ) -> RecentBest? {
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { $0.exerciseId == exerciseId }
        )
        let instances: [SessionExercise]
        do {
            instances = try context.fetch(descriptor)
        } catch {
            return nil
        }

        // (sessionDate, completed sets) newest-first, finished sessions only.
        let past: [(date: Date, sets: [WorkSet])] = instances
            .compactMap { se in
                guard let session = se.session,
                      session.endedAt != nil,
                      session.id != sessionId
                else { return nil }
                let completed = (se.sets ?? []).filter { $0.completedAt != nil && !$0.skipped }
                guard !completed.isEmpty else { return nil }
                return (session.startedAt, completed)
            }
            .sorted { $0.date > $1.date }

        guard !past.isEmpty else { return nil }

        // Preferred: newest session containing a set inside the target range.
        if let targetReps {
            for entry in past {
                let inRange = entry.sets.filter { targetReps.contains($0.reps) }
                if let top = inRange.max(by: setOrder) {
                    return RecentBest(
                        weightKg: top.weightKg,
                        reps: top.reps,
                        date: entry.date,
                        withinTarget: true
                    )
                }
            }
        }

        // Fallback: newest session's top set, whatever the rep count.
        guard let latest = past.first, let top = latest.sets.max(by: setOrder) else {
            return nil
        }
        return RecentBest(
            weightKg: top.weightKg,
            reps: top.reps,
            date: latest.date,
            withinTarget: false
        )
    }

    /// Top set of the most recent completed session of `exerciseId` that
    /// started strictly before `date`.
    ///
    /// Powers the session-over-session delta in History detail — D-003 defines
    /// progress as lifting more weight or more reps, and this is the pair of
    /// numbers that comparison needs.
    static func previousTopSet(
        for exerciseId: String,
        before date: Date,
        in context: ModelContext
    ) -> (weightKg: Double, reps: Int)? {
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { $0.exerciseId == exerciseId }
        )
        guard let instances = try? context.fetch(descriptor) else { return nil }

        let past: [(date: Date, sets: [WorkSet])] = instances
            .compactMap { se in
                guard let session = se.session,
                      session.endedAt != nil,
                      session.startedAt < date
                else { return nil }
                let completed = (se.sets ?? []).filter { $0.completedAt != nil && !$0.skipped }
                guard !completed.isEmpty else { return nil }
                return (session.startedAt, completed)
            }
            .sorted { $0.date > $1.date }

        guard let latest = past.first, let top = latest.sets.max(by: setOrder) else {
            return nil
        }
        return (top.weightKg, top.reps)
    }

    // MARK: - PR detection

    /// A per-rep-count personal record achieved during a specific session
    /// (D-023). Reps + weight uniquely identify a PR moment.
    struct AchievedPR: Hashable, Identifiable {
        let exerciseId: String
        let exerciseName: String
        let reps: Int
        let weightKg: Double

        var id: String { "\(exerciseId)-\(reps)" }
    }

    /// Detect PRs earned in `session` by comparing its completed non-skipped
    /// sets against all-time PRs from *earlier* sessions.
    ///
    /// A set at rep count R with weight W constitutes a PR if W strictly
    /// exceeds every historical weight recorded at exactly R reps, across
    /// completed sessions started before this one. Only the heaviest PR per
    /// (exercise, reps) is returned.
    static func prsAchieved(
        in session: Session,
        context: ModelContext
    ) -> [AchievedPR] {
        let currentExercises = (session.exercises ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
        guard !currentExercises.isEmpty else { return [] }

        var achieved: [String: AchievedPR] = [:]  // key = "exerciseId-reps"

        for se in currentExercises {
            let completed = (se.sets ?? [])
                .filter { $0.completedAt != nil && !$0.skipped }
            guard !completed.isEmpty else { continue }

            let historicalMaxes = historicalRepMaxes(
                for: se.exerciseId,
                before: session.startedAt,
                context: context
            )

            for s in completed where s.durationSeconds == nil {
                let previousBest = historicalMaxes[s.reps] ?? 0
                guard s.weightKg > previousBest else { continue }

                let key = "\(se.exerciseId)-\(s.reps)"
                if let existing = achieved[key], existing.weightKg >= s.weightKg {
                    continue
                }
                achieved[key] = AchievedPR(
                    exerciseId: se.exerciseId,
                    exerciseName: se.exerciseNameSnapshot,
                    reps: s.reps,
                    weightKg: s.weightKg
                )
            }
        }

        // Stable ordering: by exercise name, then by rep count.
        return achieved.values.sorted { a, b in
            if a.exerciseName != b.exerciseName {
                return a.exerciseName.localizedCaseInsensitiveCompare(b.exerciseName) == .orderedAscending
            }
            return a.reps < b.reps
        }
    }

    /// Heaviest weight ever recorded at each rep count for `exerciseId`,
    /// across sessions that started strictly before `cutoff`.
    private static func historicalRepMaxes(
        for exerciseId: String,
        before cutoff: Date,
        context: ModelContext
    ) -> [Int: Double] {
        let descriptor = FetchDescriptor<SessionExercise>(
            predicate: #Predicate<SessionExercise> { $0.exerciseId == exerciseId }
        )
        let instances: [SessionExercise]
        do {
            instances = try context.fetch(descriptor)
        } catch {
            return [:]
        }

        var maxes: [Int: Double] = [:]
        for se in instances {
            guard let session = se.session,
                  session.startedAt < cutoff,
                  session.endedAt != nil
            else { continue }

            for s in (se.sets ?? []) where s.completedAt != nil && !s.skipped && s.durationSeconds == nil {
                let existing = maxes[s.reps] ?? 0
                if s.weightKg > existing {
                    maxes[s.reps] = s.weightKg
                }
            }
        }
        return maxes
    }
}
