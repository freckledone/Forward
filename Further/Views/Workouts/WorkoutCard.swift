import SwiftUI

/// Fitness-tile-inspired card for a Workout on Home (Design System §7, D-043).
///
/// The whole card is one tap target and it **starts the workout** (D-075).
/// Starting is what you came to Home to do; editing is the rare case, and it
/// lives on swipe and long-press instead.
///
/// That also collapses the card back to a single button. It previously held
/// two sibling buttons so a tap could mean either thing, which needed each
/// half to define its own hit area. The play glyph is now decoration — it
/// signals what a tap does rather than being separately tappable.
///
/// - 20pt padding + 20pt continuous corner radius
/// - Muscle-group-tinted gradient background (derived from the first exercise's
///   first primary muscle)
/// - Subtle shadow (§7)
struct WorkoutCard: View {
    let workout: Workout
    let onStart: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ExerciseCatalog.self) private var catalog

    private var orderedExercises: [WorkoutExercise] {
        (workout.exercises ?? []).sorted { $0.displayOrder < $1.displayOrder }
    }

    /// Card tint — user override if set, else derived from the first
    /// exercise's first primary muscle.
    private var tintMuscle: MuscleGroup? {
        if let override = workout.tintOverride { return override }
        guard let firstId = orderedExercises.first?.exerciseId,
              let exercise = catalog.exercise(withId: firstId) else { return nil }
        return exercise.primaryMuscles.first
    }

    /// Distinct primary muscles the workout covers, in first-appearance order.
    ///
    /// Replaces the old "three exercise names, then +5 more" preview: three
    /// arbitrary names told you less about the workout than its muscle
    /// coverage does, and the "+N more" line was a truncation artifact
    /// wearing the costume of information.
    private var muscleCoverage: [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for we in orderedExercises {
            guard let exercise = catalog.exercise(withId: we.exerciseId),
                  let muscle = exercise.primaryMuscles.first,
                  !seen.contains(muscle)
            else { continue }
            seen.append(muscle)
        }
        return Array(seen.prefix(3))
    }

    /// "8 exercises · 24 sets". Unlike History, these counts *do* vary from
    /// one workout to the next, so here they distinguish rather than pad.
    private var countsLine: String {
        let exerciseCount = orderedExercises.count
        let setCount = orderedExercises.reduce(0) { $0 + max($1.targetSets, 0) }

        var parts = [exerciseCount == 1 ? "1 exercise" : "\(exerciseCount) exercises"]
        if setCount > 0 {
            parts.append(setCount == 1 ? "1 set" : "\(setCount) sets")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onStart) {
            // Centered so the play glyph sits opposite the middle of the
            // exercise list rather than riding the title's baseline.
            HStack(alignment: .center, spacing: 16) {
                summary
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    // play.fill's visual mass sits left of its glyph box.
                    .offset(x: 2)
                    .frame(width: 54, height: 54)
                    .background {
                        Circle().fill(Color.accentColor.opacity(0.12))
                    }
                    .accessibilityHidden(true)
            }
            .padding(20)
            .cardSurface(tint: tintMuscle)
            .contentShape(
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(workout.name.isEmpty ? "Untitled" : workout.name)")
        .accessibilityHint(countsLine)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.name.isEmpty ? "Untitled" : workout.name)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if orderedExercises.isEmpty {
                Text("No exercises yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(countsLine)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !muscleCoverage.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(muscleCoverage, id: \.self) { muscle in
                            muscleChip(muscle)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    /// The muscle color carries the meaning through the capsule fill; the
    /// label stays on a system text style, because these tints are pastel and
    /// would fail contrast as foreground on a light card.
    private func muscleChip(_ muscle: MuscleGroup) -> some View {
        Text(muscle.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(MuscleTint.chipFill(for: muscle, colorScheme: colorScheme))
            }
    }
}
