import SwiftUI
import SwiftData
import AppGymKit

/// Historical sessions are fully editable: date, notes, exercises, sets,
/// weight and reps. Edits mutate the stored session directly — there is no
/// separate "draft" state — and never touch the source template.
struct HistoryDetailView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingExercisePicker = false
    @State private var isPresentingDeleteConfirmation = false
    @State private var entryPendingRemoval: ExerciseEntry?

    var body: some View {
        List {
            Section {
                DatePicker("Fecha", selection: $session.date, displayedComponents: [.date, .hourAndMinute])
                    .onChange(of: session.date) { _, _ in save() }

                TextField("Nota (opcional)", text: notesBinding, axis: .vertical)
                    .onChange(of: session.notes) { _, _ in save() }
            }

            ForEach(session.orderedEntries) { entry in
                Section {
                    ForEach(entry.orderedSets) { set in
                        HistorySetRowView(set: set, onChange: save)
                    }
                    .onDelete { offsets in removeSets(at: offsets, from: entry) }

                    Button {
                        addSet(to: entry)
                    } label: {
                        Label("Añadir serie", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text(entry.exercise?.name ?? "Ejercicio")
                        Spacer()
                        Button(role: .destructive) {
                            entryPendingRemoval = entry
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                                .contentShape(Rectangle())
                        }
                    }
                }
            }

            Section {
                Button {
                    isPresentingExercisePicker = true
                } label: {
                    Label("Añadir ejercicio", systemImage: "plus")
                }
            }

            Section {
                Button(role: .destructive) {
                    isPresentingDeleteConfirmation = true
                } label: {
                    Text("Eliminar entrenamiento")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(session.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingExercisePicker) {
            ExercisePickerView(excludedIDs: Set(session.entries.compactMap { $0.exercise?.id })) { added in
                addExercises(added)
            }
        }
        .confirmationDialog(
            "¿Eliminar este entrenamiento?",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .confirmationDialog(
            "¿Quitar \(entryPendingRemoval?.exercise?.name ?? "este ejercicio")?",
            isPresented: .constant(entryPendingRemoval != nil),
            titleVisibility: .visible
        ) {
            Button("Quitar", role: .destructive) {
                if let entry = entryPendingRemoval { removeExercise(entry) }
                entryPendingRemoval = nil
            }
            Button("Cancelar", role: .cancel) { entryPendingRemoval = nil }
        } message: {
            Text("Se perderán las series registradas para este ejercicio en esta sesión.")
        }
    }

    private var notesBinding: Binding<String> {
        Binding(get: { session.notes ?? "" }, set: { session.notes = $0.isEmpty ? nil : $0 })
    }

    private func addSet(to entry: ExerciseEntry) {
        let nextOrder = (entry.sets.map(\.order).max() ?? -1) + 1
        entry.sets.append(SetEntry(order: nextOrder, isCompleted: true))
        save()
    }

    private func removeSets(at offsets: IndexSet, from entry: ExerciseEntry) {
        let ordered = entry.orderedSets
        for index in offsets {
            let set = ordered[index]
            entry.sets.removeAll { $0.id == set.id }
            context.delete(set)
        }
        save()
    }

    private func addExercises(_ exercises: [Exercise]) {
        let startingOrder = (session.entries.map(\.order).max() ?? -1) + 1
        for (offset, exercise) in exercises.enumerated() {
            let entry = ExerciseEntry(order: startingOrder + offset, exercise: exercise)
            entry.sets.append(SetEntry(order: 0, isCompleted: true))
            session.entries.append(entry)
        }
        save()
    }

    private func removeExercise(_ entry: ExerciseEntry) {
        session.entries.removeAll { $0.id == entry.id }
        context.delete(entry)
        save()
    }

    private func save() {
        try? context.save()
    }
}

private struct HistorySetRowView: View {
    @Bindable var set: SetEntry
    let onChange: () -> Void

    var body: some View {
        HStack {
            Text("Serie \(set.order + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            TextField("kg", text: weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())

            Text("×")
                .foregroundStyle(.secondary)

            TextField("reps", text: repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
        }
    }

    private var weightText: Binding<String> {
        Binding(
            get: { set.weight.map { $0.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", $0) : String(format: "%.1f", $0) } ?? "" },
            set: { newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                if normalized.isEmpty {
                    set.weight = nil
                } else if let parsed = Double(normalized), parsed >= 0 {
                    set.weight = parsed
                }
                onChange()
            }
        )
    }

    private var repsText: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : String(set.reps) },
            set: { newValue in
                if newValue.isEmpty {
                    set.reps = 0
                } else if let parsed = Int(newValue), parsed >= 0 {
                    set.reps = parsed
                }
                onChange()
            }
        )
    }
}
