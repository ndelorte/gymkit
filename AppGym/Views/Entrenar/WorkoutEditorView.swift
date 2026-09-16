import SwiftUI
import SwiftData
import AppGymKit

/// Create or edit a `WorkoutTemplate`. Editing rebuilds the template's item
/// list from scratch on save — templates are lightweight and this keeps the
/// logic simple, and it never touches past `WorkoutSession` snapshots.
struct WorkoutEditorView: View {
    let template: WorkoutTemplate?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var items: [EditableTemplateItem]
    @State private var isPresentingPicker = false
    @State private var saveError: String?

    init(template: WorkoutTemplate?) {
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _items = State(initialValue: template?.orderedExerciseItems.compactMap { item in
            item.exercise.map { EditableTemplateItem(exercise: $0, setCount: item.initialSetCount) }
        } ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("p. ej. Push A", text: $name)
                        .accessibilityIdentifier("templateNameField")
                }

                Section("Ejercicios") {
                    if items.isEmpty {
                        Text("Añade al menos un ejercicio")
                            .foregroundStyle(.secondary)
                    }
                    ForEach($items) { $item in
                        HStack {
                            Text(item.exercise.name)
                            Spacer()
                            Stepper("\(item.setCount) series", value: $item.setCount, in: 1...10)
                                .fixedSize()
                        }
                    }
                    .onMove { indices, newOffset in
                        items.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indices in
                        items.remove(atOffsets: indices)
                    }

                    Button {
                        isPresentingPicker = true
                    } label: {
                        Label("Añadir ejercicio", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addExerciseToTemplateButton")
                }
            }
            .environment(\.editMode, .constant(items.isEmpty ? .inactive : .active))
            .navigationTitle(template == nil ? "Nuevo entrenamiento" : "Editar entrenamiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveTemplateButton")
                }
            }
            .sheet(isPresented: $isPresentingPicker) {
                ExercisePickerView(excludedIDs: Set(items.map(\.exercise.id))) { added in
                    for exercise in added {
                        items.append(EditableTemplateItem(exercise: exercise, setCount: 3))
                    }
                }
            }
        }
        .persistenceErrorAlert($saveError)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target = template ?? WorkoutTemplate(name: trimmedName)
        target.name = trimmedName

        for existingItem in target.exerciseItems {
            context.delete(existingItem)
        }
        target.exerciseItems.removeAll()

        for (index, editable) in items.enumerated() {
            let newItem = TemplateExerciseItem(order: index, initialSetCount: editable.setCount, exercise: editable.exercise)
            newItem.template = target
            target.exerciseItems.append(newItem)
        }

        if template == nil {
            context.insert(target)
        }

        // Only leave the form if the save actually persisted — otherwise the
        // sheet would close as if the template were saved when it wasn't.
        if let error = PersistenceResult.save(context) {
            saveError = error
        } else {
            dismiss()
        }
    }
}

private struct EditableTemplateItem: Identifiable {
    let id = UUID()
    let exercise: Exercise
    var setCount: Int
}
