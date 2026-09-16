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
                TextField("kg", text: weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                    .frame(width: 58)
                    .accessibilityIdentifier("\(identifierPrefix)_weight")
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            HStack(spacing: 4) {
                TextField("reps", text: repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.monospacedDigit())
                    .frame(width: 36)
                    .accessibilityIdentifier("\(identifierPrefix)_reps")
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
        let weightText = previous.weight.map { formatWeight($0) } ?? "–"
        return "Anterior: \(weightText)×\(previous.reps)"
    }

    private var weightText: Binding<String> {
        Binding(
            get: { set.weight.map(formatWeight) ?? "" },
            set: { newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                set.weight = Double(normalized)
                onChange()
            }
        )
    }

    private var repsText: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : String(set.reps) },
            set: { newValue in
                set.reps = Int(newValue) ?? 0
                onChange()
            }
        )
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
