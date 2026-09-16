import SwiftUI
import SwiftData
import Charts
import AppGymKit

struct ExerciseDetailView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context

    private var history: [(session: WorkoutSession, entry: ExerciseEntry)] {
        PreviousSessionFinder.history(for: exercise, context: context)
    }

    private var chartPoints: [ExerciseChartPoint] {
        ExerciseProgress.chartPoints(for: exercise, context: context)
    }

    private var maxWeight: Double? {
        PersonalRecordCalculator.maxCompletedWeight(for: exercise, context: context)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    StatTile(title: "Última sesión", value: history.first.map { $0.session.date.formatted(date: .abbreviated, time: .omitted) } ?? "—")
                    StatTile(title: "Peso máximo", value: maxWeight.map { formatWeight($0) + " kg" } ?? "—")
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }

            if chartPoints.count > 1 {
                Section("Progresión") {
                    Chart(chartPoints) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("Peso máx.", point.maxWeight))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Fecha", point.date), y: .value("Peso máx.", point.maxWeight))
                    }
                    .frame(height: 180)
                    .padding(.vertical, 8)
                }
            }

            Section("Historial") {
                if history.isEmpty {
                    Text("Todavía no hay sesiones registradas para este ejercicio.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history, id: \.session.id) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.session.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.medium))
                            ForEach(item.entry.orderedSets) { set in
                                HStack {
                                    Text("\(formatWeight(set.weight ?? 0)) kg × \(set.reps)")
                                        .font(.callout.monospacedDigit())
                                    if PersonalRecordCalculator.isPersonalRecord(set, exercise: exercise, context: context) {
                                        Image(systemName: "trophy.fill")
                                            .foregroundStyle(Theme.prGold)
                                            .font(.caption)
                                            .accessibilityIdentifier("prBadge_\(set.id)")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
