import SwiftUI
import SwiftData
import AppGymKit

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @State private var isPresentingExercisePicker = false
    @State private var isPresentingFinishConfirmation = false
    @State private var isPresentingNotes = false
    @State private var isReordering = false
    @State private var finishError: String?

    var body: some View {
        List {
            ForEach(session.orderedEntries) { entry in
                Section {
                    ForEach(entry.orderedSets) { set in
                        SetRowView(
                            set: set,
                            previous: previousSet(for: entry, index: set.order),
                            isPersonalRecord: isPersonalRecord(set, entry: entry),
                            onChange: save,
                            identifierPrefix: "\(entry.exercise?.name ?? "ejercicio")_\(set.order)"
                        )
                    }
                    .onDelete { offsets in
                        removeSets(at: offsets, from: entry)
                    }

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
                            removeExercise(entry)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .onMove(perform: moveExercises)

            Section {
                Button {
                    isPresentingExercisePicker = true
                } label: {
                    Label("Añadir ejercicio", systemImage: "plus")
                }
                Button {
                    isPresentingNotes = true
                } label: {
                    Label(session.notes?.isEmpty == false ? "Editar nota" : "Añadir nota", systemImage: "note.text")
                }
            }

            Section {
                Button(role: .destructive) {
                    isPresentingFinishConfirmation = true
                } label: {
                    Text("Finalizar entrenamiento")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("finishWorkoutButton")
            }
        }
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        .navigationTitle(session.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isReordering ? "Listo" : "Reordenar") {
                    isReordering.toggle()
                }
            }
        }
        .sheet(isPresented: $isPresentingExercisePicker) {
            ExercisePickerView(excludedIDs: Set(session.entries.compactMap { $0.exercise?.id })) { added in
                addExercises(added)
            }
        }
        .sheet(isPresented: $isPresentingNotes) {
            NotesEditorView(text: session.notes ?? "") { newText in
                session.notes = newText.isEmpty ? nil : newText
                save()
            }
        }
        .confirmationDialog(
            "¿Finalizar entrenamiento?",
            isPresented: $isPresentingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finalizar", role: .destructive, action: finish)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las series no marcadas como completadas no se guardarán.")
        }
        .alert("No se pudo finalizar", isPresented: .constant(finishError != nil), actions: {
            Button("OK") { finishError = nil }
        }, message: {
            Text(finishError ?? "")
        })
    }

    // MARK: - Previous session reference

    private func previousSet(for entry: ExerciseEntry, index: Int) -> SetEntry? {
        guard let exercise = entry.exercise else { return nil }
        let previous = PreviousSessionFinder.mostRecentCompletedEntry(
            for: exercise,
            excludingSessionID: session.id,
            context: context
        )
        let sets = previous?.entry.orderedSets ?? []
        return index < sets.count ? sets[index] : nil
    }

    private func isPersonalRecord(_ set: SetEntry, entry: ExerciseEntry) -> Bool {
        guard let exercise = entry.exercise, set.isCompleted else { return false }
        return PersonalRecordCalculator.isPersonalRecord(set, exercise: exercise, context: context)
    }

    // MARK: - Mutations

    private func addSet(to entry: ExerciseEntry) {
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
            let previous = PreviousSessionFinder.mostRecentCompletedEntry(for: exercise, context: context)
            let previousSets = previous?.entry.orderedSets ?? []
            let setCount = max(previousSets.count, 3)
            for index in 0..<setCount {
                let previousSet = index < previousSets.count ? previousSets[index] : nil
                entry.sets.append(SetEntry(order: index, weight: previousSet?.weight, reps: previousSet?.reps ?? 0))
            }
            session.entries.append(entry)
        }
        save()
    }

    private func removeExercise(_ entry: ExerciseEntry) {
        session.entries.removeAll { $0.id == entry.id }
        context.delete(entry)
        save()
    }

    private func moveExercises(from indices: IndexSet, to offset: Int) {
        var ordered = session.orderedEntries
        ordered.move(fromOffsets: indices, toOffset: offset)
        for (index, entry) in ordered.enumerated() {
            entry.order = index
        }
        save()
    }

    private func finish() {
        do {
            try WorkoutSessionService.finish(session, context: context)
            Haptics.setCompleted()
        } catch {
            finishError = error.localizedDescription
        }
    }

    private func save() {
        try? context.save()
    }
}

private struct NotesEditorView: View {
    @State var text: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Nota")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar") {
                            onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
        }
    }
}
