import SwiftUI
import AppGymKit

/// A single set row during an active workout: previous-session reference,
/// weight/reps entry, and a large tap target to mark it completed.
/// Marking complete is the only action that "counts" a set as performed —
/// everything else here is just editing pre-populated or fresh values.
struct SetRowView: View {
    @Bindable var set: SetEntry
    let previous: SetEntry?
    let isPersonalRecord: Bool
    let onChange: () -> Void
    var identifierPrefix: String = "set"

    /// Editing text is deliberately its own state, not re-derived from
    /// `set.weight`/`set.reps` on every render: that would reformat (or
    /// clobber) what the user is mid-way through typing — e.g. "82." getting
    /// snapped back to "82" before they type the digit after the decimal
    /// point. It's seeded once from the model and only the model is written
    /// to as it changes; the displayed text is never rewritten out from
    /// under the user.
    @State private var weightText: String
    @State private var repsText: String

    init(set: SetEntry, previous: SetEntry?, isPersonalRecord: Bool, onChange: @escaping () -> Void, identifierPrefix: String = "set") {
        self.set = set
        self.previous = previous
        self.isPersonalRecord = isPersonalRecord
        self.onChange = onChange
        self.identifierPrefix = identifierPrefix
        _weightText = State(initialValue: WeightFormatting.string(for: set.weight))
        _repsText = State(initialValue: set.reps == 0 ? "" : String(set.reps))
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Serie \(set.order + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let previous {
                    Text(previousLabel(previous))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else {
                    Text("Sin datos previos")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 84, alignment: .leading)

            HStack(spacing: 4) {
                TextField("kg", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                    .frame(width: 58)
                    .accessibilityIdentifier("\(identifierPrefix)_weight")
                    .onChange(of: weightText) { _, newValue in applyWeight(newValue) }
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            HStack(spacing: 4) {
                TextField("reps", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                    .frame(width: 36)
                    .accessibilityIdentifier("\(identifierPrefix)_reps")
                    .onChange(of: repsText) { _, newValue in applyReps(newValue) }
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Spacer(minLength: 0)

            if isPersonalRecord {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(Theme.prGold)
                    .accessibilityIdentifier("\(identifierPrefix)_prBadge")
            }

            Button {
                // A set with no weight and no reps hasn't actually happened —
                // don't let it be marked completed (see `hasRecordedPerformance`).
                guard set.isCompleted || set.hasRecordedPerformance else { return }
                set.isCompleted.toggle()
                if set.isCompleted { Haptics.setCompleted() }
                onChange()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(set.isCompleted ? Theme.completedGreen : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            .accessibilityIdentifier("\(identifierPrefix)_complete")
            .accessibilityValue(set.isCompleted ? "completado" : "pendiente")
        }
        .padding(.vertical, 4)
    }

    private func previousLabel(_ previous: SetEntry) -> String {
        let weightText = WeightFormatting.string(for: previous.weight)
        return "Anterior: \(weightText.isEmpty ? "–" : weightText)×\(previous.reps)"
    }

    private func applyWeight(_ newValue: String) {
        switch WeightFormatting.parse(newValue) {
        case .empty:
            set.weight = nil
        case .value(let parsed):
            set.weight = parsed
        case .invalid:
            break // leave the last valid value untouched while the user keeps typing
        }
        onChange()
    }

    private func applyReps(_ newValue: String) {
        if newValue.isEmpty {
            set.reps = 0
        } else if let parsed = Int(newValue), parsed >= 0 {
            set.reps = parsed
        }
        onChange()
    }
}
