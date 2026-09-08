import SwiftUI

/// Reusable filter chip row for exercise-picking screens (ExercisePicker,
/// ExerciseBrowser). Two Menu-picker pills — muscle and equipment — plus a
/// clear-all button that only appears when at least one filter is active.
///
/// Chips follow the Design System §7 aesthetic: accent-tinted capsules,
/// rounded-design labels, chevron affordance.
///
/// Layout notes:
///  - Pills use `.fixedSize` so multi-word labels never wrap character-by-character.
///  - Horizontal ScrollView so content can overflow on narrow devices without
///    truncating; a `ScrollViewReader` snaps back to leading whenever a filter
///    changes, preventing the "half-clipped after selection" glitch.
///  - No `.animation` modifiers on the container — implicit animations inside
///    a horizontal ScrollView interact badly with Menu dismissal.
struct ExerciseFilterBar: View {
    @Binding var muscle: MuscleGroup?
    @Binding var equipment: Equipment?

    private let leadingAnchorID = "filter-bar-leading"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .id(leadingAnchorID)
                    muscleMenu
                    equipmentMenu
                    if muscle != nil || equipment != nil {
                        clearButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onChange(of: muscle) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(leadingAnchorID, anchor: .leading)
                }
            }
            .onChange(of: equipment) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(leadingAnchorID, anchor: .leading)
                }
            }
        }
    }

    // MARK: - Muscle menu

    private var muscleMenu: some View {
        Menu {
            Picker("Muscle", selection: $muscle) {
                Text("All muscles").tag(MuscleGroup?.none)
                ForEach(MuscleGroup.allCases, id: \.self) { m in
                    Text(m.displayName).tag(MuscleGroup?.some(m))
                }
            }
        } label: {
            filterPill(
                text: muscle?.displayName ?? "Muscle",
                active: muscle != nil
            )
        }
    }

    // MARK: - Equipment menu

    private var equipmentMenu: some View {
        Menu {
            Picker("Equipment", selection: $equipment) {
                Text("All equipment").tag(Equipment?.none)
                ForEach(Equipment.allCases, id: \.self) { e in
                    Text(e.displayName).tag(Equipment?.some(e))
                }
            }
        } label: {
            filterPill(
                text: equipment?.displayName ?? "Equipment",
                active: equipment != nil
            )
        }
    }

    // MARK: - Clear button

    private var clearButton: some View {
        Button {
            muscle = nil
            equipment = nil
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("Clear")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fixedSize(horizontal: true, vertical: false)
            .background {
                Capsule().fill(Color(.tertiarySystemFill))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pill

    private func filterPill(text: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(active ? Color.accentColor : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .fixedSize(horizontal: true, vertical: false)
        .background {
            Capsule().fill(
                active
                    ? Color.accentColor.opacity(0.14)
                    : Color(.tertiarySystemFill)
            )
        }
        .contentShape(Capsule())
    }
}
