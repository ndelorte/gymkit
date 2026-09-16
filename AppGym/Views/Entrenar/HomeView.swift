import SwiftUI
import SwiftData
import AppGymKit

struct HomeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse)
    private var templates: [WorkoutTemplate]

    @Query(filter: #Predicate<WorkoutSession> { !$0.isActive }, sort: \WorkoutSession.date, order: .reverse)
    private var recentSessions: [WorkoutSession]

    @State private var isPresentingNewTemplate = false
    @State private var templateToEdit: WorkoutTemplate?
    @State private var startError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header

                if templates.isEmpty {
                    emptyTemplatesCard
                } else {
                    templatesSection
                }

                if !recentSessions.isEmpty {
                    recentSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AppGym")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingNewTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuevo entrenamiento")
                .accessibilityIdentifier("newTemplateButton")
            }
        }
        .sheet(isPresented: $isPresentingNewTemplate) {
            WorkoutEditorView(template: nil)
        }
        .sheet(item: $templateToEdit) { template in
            WorkoutEditorView(template: template)
        }
        .alert("No se pudo iniciar", isPresented: .constant(startError != nil), actions: {
            Button("OK") { startError = nil }
        }, message: {
            Text(startError ?? "")
        })
    }

    private var header: some View {
        Text("Empieza a entrenar")
            .font(.largeTitle.bold())
    }

    private var emptyTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aún no tienes entrenamientos")
                .font(.headline)
            Text("Crea tu primer entrenamiento reutilizable para empezar a registrar series.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                isPresentingNewTemplate = true
            } label: {
                Label("Crear entrenamiento", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("emptyStateCreateTemplate")
        }
        .cardStyle()
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tus entrenamientos")
                .font(.title3.bold())

            ForEach(templates) { template in
                TemplateCard(template: template) {
                    startSession(from: template)
                } onEdit: {
                    templateToEdit = template
                } onDelete: {
                    deleteTemplate(template)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recientes")
                .font(.title3.bold())

            ForEach(recentSessions.prefix(5)) { session in
                NavigationLink {
                    HistoryDetailView(session: session)
                } label: {
                    RecentSessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startSession(from template: WorkoutTemplate) {
        do {
            try WorkoutSessionService.startSession(from: template, context: context)
            Haptics.lightTap()
        } catch {
            startError = error.localizedDescription
        }
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        context.delete(template)
        try? context.save()
    }
}

private struct TemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                    Text(exerciseSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Editar", systemImage: "pencil", action: onEdit)
                    Button("Eliminar", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onStart) {
                Label("Iniciar", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("startTemplate_\(template.name)")
        }
        .cardStyle()
    }

    private var exerciseSummary: String {
        let count = template.exerciseItems.count
        return count == 1 ? "1 ejercicio" : "\(count) ejercicios"
    }
}

private struct RecentSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.templateName)
                    .font(.body.weight(.medium))
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(session.entries.count) ej.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
