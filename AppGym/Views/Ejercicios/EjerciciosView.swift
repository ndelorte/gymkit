import SwiftUI
import SwiftData
import AppGymKit

struct EjerciciosView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var showArchived = false
    @State private var isPresentingNewExercise = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isPresentingImportConfirmation = false
    @State private var pendingImportURL: URL?
    @State private var exportDocument: BackupDocument?
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedExercises, id: \.0) { group, exercises in
                    Section(group) {
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                    if exercise.isArchived {
                                        Spacer()
                                        Text("Archivado")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .swipeActions {
                                Button(exercise.isArchived ? "Reactivar" : "Archivar") {
                                    exercise.isArchived.toggle()
                                    try? context.save()
                                }
                                .tint(exercise.isArchived ? .green : .orange)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar ejercicio")
            .navigationTitle("Ejercicios")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle("Ver archivados", isOn: $showArchived)
                        .toggleStyle(.button)
                        .font(.caption)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Exportar copia de seguridad", systemImage: "square.and.arrow.up", action: startExport)
                        Button("Importar copia de seguridad", systemImage: "square.and.arrow.down") {
                            isImporting = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewExercise) {
                NewExerciseView { _ in }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "AppGym-backup"
            ) { result in
                if case .failure(let error) = result {
                    backupMessage = "No se pudo exportar: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    pendingImportURL = url
                    isPresentingImportConfirmation = true
                case .failure(let error):
                    backupMessage = "No se pudo leer el archivo: \(error.localizedDescription)"
                }
            }
            .confirmationDialog(
                "¿Reemplazar todos los datos?",
                isPresented: $isPresentingImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Importar y reemplazar", role: .destructive, action: performImport)
                Button("Cancelar", role: .cancel) { pendingImportURL = nil }
            } message: {
                Text("Esto sustituirá ejercicios, entrenamientos e historial actuales por los de la copia de seguridad.")
            }
            .alert("Copia de seguridad", isPresented: .constant(backupMessage != nil), actions: {
                Button("OK") { backupMessage = nil }
            }, message: {
                Text(backupMessage ?? "")
            })
        }
    }

    private func startExport() {
        do {
            let data = try BackupService.exportData(context: context)
            exportDocument = BackupDocument(data: data)
            isExporting = true
        } catch {
            backupMessage = "No se pudo exportar: \(error.localizedDescription)"
        }
    }

    private func performImport() {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try BackupService.importData(data, context: context)
            backupMessage = "Copia de seguridad importada correctamente."
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private var filteredExercises: [Exercise] {
        allExercises
            .filter { showArchived || !$0.isArchived }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedExercises: [(String, [Exercise])] {
        let groups = Dictionary(grouping: filteredExercises) { $0.muscleGroup ?? "Sin categoría" }
        return groups.keys.sorted().map { ($0, groups[$0]!.sorted { $0.name < $1.name }) }
    }
}
