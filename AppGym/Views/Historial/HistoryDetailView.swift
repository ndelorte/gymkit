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
    @State private var saveError: String?

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
                // Only leave the screen if the deletion actually persisted —
                // otherwise the session would still exist on disk while the
                // UI has already navigated away as if it were gone.
                if let error = PersistenceResult.save(context) {
                    saveError = error
                } else {
                    dismiss()
                }
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
        .persistenceErrorAlert($saveError)
    }

    private var notesBinding: Binding<String> {
        Binding(get: { session.notes ?? "" }, set: { session.notes = $0.isEmpty ? nil : $0 })
    }

    private func addSet(to entry: ExerciseEntry) {
        // Starts blank/not-completed, per SetEntry's own default — it only
        // becomes "performed" once the user enters real weight or reps (see
        // HistorySetRowView), never as an empty placeholder.
        let nextOrder = (entry.sets.map(\.order).max() ?? -1) + 1
        entry.sets.append(SetEntry(order: nextOrder))
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
            entry.sets.append(SetEntry(order: 0))
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
        saveError = PersistenceResult.save(context)
    }
}

/// Historical sets have no explicit completed toggle in this editor — the
/// session already happened, so a set here "is completed" exactly when it
/// records a real performance. `isCompleted` is kept in sync with reps > 0
/// rather than always forced true, so a newly added blank set doesn't get
/// persisted as an empty "performed" set until it actually has reps entered
/// (see `SetEntry.hasRecordedPerformance`).
private struct HistorySetRowView: View {
    @Bindable var set: SetEntry
    let onChange: () -> Void

    @State private var weightText: String
    @State private var repsText: String

    init(set: SetEntry, onChange: @escaping () -> Void) {
        self.set = set
        self.onChange = onChange
        _weightText = State(initialValue: WeightFormatting.string(for: set.weight))
        _repsText = State(initialValue: set.reps == 0 ? "" : String(set.reps))
    }

    var body: some View {
        HStack {
            Text("Serie \(set.order + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            TextField("kg", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
                .onChange(of: weightText) { _, newValue in applyWeight(newValue) }

            Text("×")
                .foregroundStyle(.secondary)

            TextField("reps", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
                .onChange(of: repsText) { _, newValue in applyReps(newValue) }
        }
    }

    private func applyWeight(_ newValue: String) {
        switch WeightFormatting.parse(newValue) {
        case .empty:
            set.weight = nil
        case .value(let parsed):
            set.weight = parsed
        case .invalid:
            break
        }
        set.isCompleted = set.hasRecordedPerformance
        onChange()
    }

    private func applyReps(_ newValue: String) {
        if newValue.isEmpty {
            set.reps = 0
        } else if let parsed = Int(newValue), parsed >= 0 {
            set.reps = parsed
        }
        set.isCompleted = set.hasRecordedPerformance
        onChange()
    }
}
