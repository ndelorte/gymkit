import SwiftUI
import SwiftData
import AppGymKit

struct HistorialView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<WorkoutSession> { !$0.isActive }, sort: \WorkoutSession.date, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Sin historial todavía",
                        systemImage: "clock",
                        description: Text("Termina un entrenamiento para verlo aquí.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink {
                                HistoryDetailView(session: session)
                            } label: {
                                HistoryRow(session: session)
                            }
                            .accessibilityIdentifier("historyRow_\(session.id)")
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Historial")
        }
        .persistenceErrorAlert($saveError)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
        saveError = PersistenceResult.save(context)
    }
}

private struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.templateName)
                .font(.headline)
            HStack {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                Text("·")
                Text(exerciseCountLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var exerciseCountLabel: String {
        let count = session.entries.count
        return count == 1 ? "1 ejercicio" : "\(count) ejercicios"
    }
}
