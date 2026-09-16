import SwiftUI
import SwiftData
import AppGymKit

/// Sheet for selecting one or more library exercises, with an inline path to
/// create a custom exercise that immediately becomes part of the library.
struct ExercisePickerView: View {
    let excludedIDs: Set<UUID>
    let onAdd: ([Exercise]) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var isPresentingNewExercise = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredExercises) { exercise in
                    Button {
                        toggle(exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                                if let group = exercise.muscleGroup {
                                    Text(group)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if selectedIDs.contains(exercise.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                        .frame(minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("exercisePickerRow_\(exercise.name)")
                }
            }
            .searchable(text: $searchText, prompt: "Buscar ejercicio")
            .navigationTitle("Ejercicios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        let selected = exercises.filter { selectedIDs.contains($0.id) }
                        onAdd(selected)
                        dismiss()
                    } label: {
                        Text(selectedIDs.isEmpty ? "Añadir" : "Añadir (\(selectedIDs.count))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIDs.isEmpty)
                    .accessibilityIdentifier("confirmAddExercisesButton")
                }
            }
            .sheet(isPresented: $isPresentingNewExercise) {
                NewExerciseView { newExercise in
                    selectedIDs.insert(newExercise.id)
                }
            }
        }
    }

    private var filteredExercises: [Exercise] {
        let base = exercises.filter { !excludedIDs.contains($0.id) }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else {
            selectedIDs.insert(exercise.id)
        }
    }
}

/// Inline creation form for a custom exercise. Saving it inserts the exercise
/// into the shared library — it's reusable from that point on, same as any
/// seeded exercise.
struct NewExerciseView: View {
    var onCreate: (Exercise) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscleGroup = ""

    private let suggestedGroups = ["Pecho", "Espalda", "Piernas", "Hombros", "Brazos", "Core"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("p. ej. Press banca", text: $name)
                }
                Section("Grupo muscular (opcional)") {
                    TextField("p. ej. Pecho", text: $muscleGroup)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestedGroups, id: \.self) { group in
                                Button(group) { muscleGroup = group }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nuevo ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedGroup = muscleGroup.trimmingCharacters(in: .whitespaces)
        let exercise = Exercise(name: trimmedName, muscleGroup: trimmedGroup.isEmpty ? nil : trimmedGroup)
        context.insert(exercise)
        try? context.save()
        onCreate(exercise)
        dismiss()
    }
}
