import Foundation
import SwiftData

public enum BackupService {

    // MARK: - Export

    @MainActor
    public static func exportData(context: ModelContext) throws -> Data {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []

        let dto = BackupDTO(
            version: BackupDTO.currentVersion,
            exercises: exercises.map {
                ExerciseDTO(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, isArchived: $0.isArchived, createdAt: $0.createdAt)
            },
            templates: templates.map { template in
                WorkoutTemplateDTO(
                    id: template.id,
                    name: template.name,
                    createdAt: template.createdAt,
                    items: template.orderedExerciseItems.compactMap { item in
                        guard let exerciseID = item.exercise?.id else { return nil }
                        return TemplateExerciseItemDTO(id: item.id, order: item.order, initialSetCount: item.initialSetCount, exerciseID: exerciseID)
                    }
                )
            },
            sessions: sessions.map { session in
                WorkoutSessionDTO(
                    id: session.id,
                    templateName: session.templateName,
                    sourceTemplateID: session.sourceTemplateID,
                    date: session.date,
                    notes: session.notes,
                    isActive: session.isActive,
                    entries: session.orderedEntries.compactMap { entry in
                        guard let exerciseID = entry.exercise?.id else { return nil }
                        return ExerciseEntryDTO(
                            id: entry.id,
                            order: entry.order,
                            exerciseID: exerciseID,
                            sets: entry.orderedSets.map {
                                SetEntryDTO(id: $0.id, order: $0.order, weight: $0.weight, reps: $0.reps, isCompleted: $0.isCompleted)
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dto)
    }

    // MARK: - Validation

    /// Decodes and validates referential integrity without touching the store.
    /// Throws `AppGymError.invalidBackup` describing the first problem found.
    public static func validate(_ data: Data) throws -> BackupDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto: BackupDTO
        do {
            dto = try decoder.decode(BackupDTO.self, from: data)
        } catch {
            throw AppGymError.invalidBackup(reason: "el JSON no tiene el formato esperado")
        }

        guard dto.version == BackupDTO.currentVersion else {
            throw AppGymError.invalidBackup(reason: "versión de copia de seguridad no soportada")
        }

        let exerciseIDs = Set(dto.exercises.map(\.id))
        guard exerciseIDs.count == dto.exercises.count else {
            throw AppGymError.invalidBackup(reason: "hay ejercicios duplicados")
        }

        let templateIDs = Set(dto.templates.map(\.id))
        guard templateIDs.count == dto.templates.count else {
            throw AppGymError.invalidBackup(reason: "hay entrenamientos duplicados")
        }

        let sessionIDs = Set(dto.sessions.map(\.id))
        guard sessionIDs.count == dto.sessions.count else {
            throw AppGymError.invalidBackup(reason: "hay sesiones duplicadas")
        }

        for template in dto.templates {
            for item in template.items {
                guard exerciseIDs.contains(item.exerciseID) else {
                    throw AppGymError.invalidBackup(reason: "un ejercicio referenciado por '\(template.name)' no existe")
                }
                guard item.initialSetCount >= 1 else {
                    throw AppGymError.invalidBackup(reason: "número de series inválido en '\(template.name)'")
                }
            }
        }

        for session in dto.sessions {
            for entry in session.entries {
                guard exerciseIDs.contains(entry.exerciseID) else {
                    throw AppGymError.invalidBackup(reason: "un ejercicio referenciado por una sesión no existe")
                }
                for set in entry.sets {
                    guard set.reps >= 0 else {
                        throw AppGymError.invalidBackup(reason: "repeticiones inválidas")
                    }
                    if let weight = set.weight, weight < 0 {
                        throw AppGymError.invalidBackup(reason: "peso inválido")
                    }
                }
            }
        }

        return dto
    }

    // MARK: - Import

    /// Validates `data`, then replaces all stored data with its contents.
    /// If anything fails after mutations begin, the context is rolled back so
    /// the existing store is left exactly as it was.
    @MainActor
    public static func importData(_ data: Data, context: ModelContext) throws {
        let dto = try validate(data)

        do {
            try context.fetch(FetchDescriptor<WorkoutSession>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<WorkoutTemplate>()).forEach { context.delete($0) }
            try context.fetch(FetchDescriptor<Exercise>()).forEach { context.delete($0) }

            var exercisesByID: [UUID: Exercise] = [:]
            for exerciseDTO in dto.exercises {
                let exercise = Exercise(
                    id: exerciseDTO.id,
                    name: exerciseDTO.name,
                    muscleGroup: exerciseDTO.muscleGroup,
                    isArchived: exerciseDTO.isArchived,
                    createdAt: exerciseDTO.createdAt
                )
                context.insert(exercise)
                exercisesByID[exercise.id] = exercise
            }

            for templateDTO in dto.templates {
                let template = WorkoutTemplate(id: templateDTO.id, name: templateDTO.name, createdAt: templateDTO.createdAt)
                context.insert(template)
                for itemDTO in templateDTO.items {
                    guard let exercise = exercisesByID[itemDTO.exerciseID] else {
                        throw AppGymError.invalidBackup(reason: "referencia de ejercicio rota durante la importación")
                    }
                    let item = TemplateExerciseItem(id: itemDTO.id, order: itemDTO.order, initialSetCount: itemDTO.initialSetCount, exercise: exercise)
                    item.template = template
                    template.exerciseItems.append(item)
                }
            }

            for sessionDTO in dto.sessions {
                // Always import as completed: restoring a backup must never
                // resurrect (or duplicate) a live in-progress session — that
                // would bypass the single-active-session invariant, which is
                // otherwise only enforced by WorkoutSessionService.
                let session = WorkoutSession(
                    id: sessionDTO.id,
                    templateName: sessionDTO.templateName,
                    sourceTemplateID: sessionDTO.sourceTemplateID,
                    date: sessionDTO.date,
                    notes: sessionDTO.notes,
                    isActive: false
                )
                context.insert(session)
                for entryDTO in sessionDTO.entries {
                    guard let exercise = exercisesByID[entryDTO.exerciseID] else {
                        throw AppGymError.invalidBackup(reason: "referencia de ejercicio rota durante la importación")
                    }
                    let entry = ExerciseEntry(id: entryDTO.id, order: entryDTO.order, exercise: exercise)
                    entry.session = session
                    for setDTO in entryDTO.sets {
                        entry.sets.append(SetEntry(id: setDTO.id, order: setDTO.order, weight: setDTO.weight, reps: setDTO.reps, isCompleted: setDTO.isCompleted))
                    }
                    session.entries.append(entry)
                }
            }

            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
