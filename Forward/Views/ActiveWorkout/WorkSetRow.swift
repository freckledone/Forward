import SwiftUI

/// Identifies one editable field of one set.
///
/// Focus lives on `ExpandedExerciseSection` rather than inside `WorkSetRow`
/// so completing a set can move the keyboard to the *next* set's weight
/// field — a row can't reach its sibling's `@FocusState`.
enum SetFieldFocus: Hashable {
    case weight(UUID)
    case reps(UUID)
}

/// One row in the current exercise's set grid.
///
/// Uniform sizing for every set — current-set emphasis is expressed only
/// through a leading accent bar and a subtly tinted background. No size,
/// font, or padding changes based on `isCurrent`.
///
/// Long-press reveals a context menu with Skip / Unskip / Delete.
/// Firing complete triggers Haptics per Design System §10.4.
///
/// Weight and reps use **String-backed** `TextField`s so deletion works
/// (a `Double`/`Int` binding can't accept an empty string). Weight = 0 is
/// rendered as an empty field, so untouched sets read as "not logged yet"
/// rather than "you did 0 kg."
struct WorkSetRow: View {
    @Bindable var workSet: WorkSet
    let displayUnit: DisplayUnit
    let isCurrent: Bool
    let onCompleteToggled: () -> Void
    let onSkipToggled: () -> Void
    let onDelete: () -> Void

    /// Shared with every sibling row via `ExpandedExerciseSection`.
    @FocusState.Binding var focusedField: SetFieldFocus?

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    private var weightFocus: SetFieldFocus { .weight(workSet.id) }
    private var repsFocus: SetFieldFocus { .reps(workSet.id) }

    private var isCompleted: Bool { workSet.completedAt != nil }
    private var isSkipped: Bool { workSet.skipped }

    var body: some View {
        HStack(spacing: 10) {
            setNumber

            weightField
                .frame(minWidth: 66, maxWidth: 92)

            Text("×")
                .font(.callout)
                .foregroundStyle(.tertiary)

            repsField
                .frame(minWidth: 40, maxWidth: 56)

            rirChip

            Spacer(minLength: 4)

            completeButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .fill(rowBackground)
        }
        .opacity(isSkipped ? 0.45 : 1.0)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .opacity(isCurrent ? 1 : 0)
        }
        .animation(.smooth(duration: 0.25), value: isCurrent)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isCompleted)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isSkipped)
        .contextMenu {
            Button {
                onSkipToggled()
            } label: {
                Label(
                    isSkipped ? "Unskip Set" : "Skip Set",
                    systemImage: isSkipped ? "arrow.uturn.backward" : "forward.end"
                )
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Set", systemImage: "trash")
            }
        }
        .onAppear {
            weightText = Self.weightString(displayWeight)
            repsText = Self.repsString(workSet.reps)
        }
        .onChange(of: workSet.weightKg) { _, _ in
            if focusedField != weightFocus {
                weightText = Self.weightString(displayWeight)
            }
        }
        .onChange(of: workSet.reps) { _, newValue in
            if focusedField != repsFocus {
                repsText = Self.repsString(newValue)
            }
        }
        .onChange(of: displayUnit) { _, _ in
            if focusedField != weightFocus {
                weightText = Self.weightString(displayWeight)
            }
        }
        .onChange(of: focusedField) { _, newFocus in
            if newFocus != weightFocus {
                weightText = Self.weightString(displayWeight)
            }
            if newFocus != repsFocus {
                repsText = Self.repsString(workSet.reps)
            }
        }
    }

    // MARK: - Pieces

    private var setNumber: some View {
        Text("\(workSet.order + 1)")
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 18, alignment: .leading)
    }

    private var weightField: some View {
        TextField(unitPlaceholder, text: $weightText)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .focused($focusedField, equals: weightFocus)
            .onChange(of: weightText) { _, newText in
                commitWeight(from: newText)
            }
    }

    private var unitPlaceholder: String {
        switch displayUnit {
        case .kg: return "kg"
        case .lb: return "lb"
        }
    }

    private var repsField: some View {
        TextField("reps", text: $repsText)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .focused($focusedField, equals: repsFocus)
            .onChange(of: repsText) { _, newText in
                commitReps(from: newText)
            }
    }

    private var rirChip: some View {
        Menu {
            Button("Clear effort") { workSet.rir = nil }
            ForEach(0...5, id: \.self) { value in
                Button("RIR \(value)") { workSet.rir = value }
            }
        } label: {
            HStack(spacing: 3) {
                Text(rirLabel)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(workSet.rir != nil ? Color.accentColor : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .fixedSize(horizontal: true, vertical: false)
            .background {
                Capsule().fill(
                    workSet.rir != nil
                        ? Color.accentColor.opacity(0.14)
                        : Color(uiColor: .tertiarySystemFill)
                )
            }
        }
        .accessibilityLabel(workSet.rir.map { "RIR \($0)" } ?? "Set effort")
    }

    private var rirLabel: String {
        workSet.rir.map { "RIR \($0)" } ?? "Effort"
    }

    private var completeButton: some View {
        Button {
            toggleComplete()
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(isCompleted ? Color.accentColor : Color.secondary)
                .symbolEffect(.bounce, value: isCompleted)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "Mark set incomplete" : "Mark set complete")
    }

    private var rowBackground: Color {
        if isCurrent {
            return Color.accentColor.opacity(0.08)
        }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    // MARK: - Weight display / conversion

    private var displayWeight: Double {
        switch displayUnit {
        case .kg: return workSet.weightKg
        case .lb: return UnitConversion.lb(fromKg: workSet.weightKg)
        }
    }

    private func setDisplayWeight(_ newValue: Double) {
        switch displayUnit {
        case .kg: workSet.weightKg = max(0, newValue)
        case .lb: workSet.weightKg = max(0, UnitConversion.kg(fromLb: newValue))
        }
    }

    // MARK: - Text ↔ number formatting

    /// Locale-independent render for the weight input field. Empty when zero
    /// so untouched sets show a unit placeholder rather than "0". Whole
    /// numbers render without a decimal; fractional values render with one
    /// decimal place. Never uses grouping separators.
    private static func weightString(_ value: Double) -> String {
        if value <= 0 { return "" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        let rounded = (value * 10).rounded() / 10
        return String(rounded)
    }

    private static func repsString(_ value: Int) -> String {
        value <= 0 ? "" : String(value)
    }

    private func commitWeight(from text: String) {
        let sanitized = text.replacingOccurrences(of: ",", with: ".")
        if sanitized.isEmpty {
            setDisplayWeight(0)
            return
        }
        guard let parsed = Double(sanitized) else { return }
        setDisplayWeight(parsed)
    }

    private func commitReps(from text: String) {
        if text.isEmpty {
            workSet.reps = 0
            return
        }
        guard let parsed = Int(text) else { return }
        workSet.reps = max(0, parsed)
    }

    // MARK: - Actions

    private func toggleComplete() {
        if isCompleted {
            workSet.completedAt = nil
        } else {
            workSet.completedAt = Date()
            workSet.skipped = false
            Haptics.setCompleted()
            onCompleteToggled()
        }
    }
}
