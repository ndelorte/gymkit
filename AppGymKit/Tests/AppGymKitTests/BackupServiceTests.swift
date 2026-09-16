import Foundation
import SwiftData
import Testing
@testable import AppGymKit

@MainActor
struct BackupServiceTests {

    @Test func exportImportRoundtripPreservesData() throws {
        let sourceContext = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca", muscleGroup: "Pecho")
        sourceContext.insert(exercise)
        let archived = Exercise(name: "Ejercicio viejo", isArchived: true)
        sourceContext.insert(archived)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 2)], context: sourceContext)
        let session = try WorkoutSessionService.startSession(from: template, context: sourceContext)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 82.5, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: sourceContext)

        let data = try BackupService.exportData(context: sourceContext)

        let destinationContext = TestSupport.makeContext()
        try BackupService.importData(data, context: destinationContext)

        let exercises = try destinationContext.fetch(FetchDescriptor<Exercise>())
        let templates = try destinationContext.fetch(FetchDescriptor<WorkoutTemplate>())
        let sessions = try destinationContext.fetch(FetchDescriptor<WorkoutSession>())

        #expect(exercises.count == 2)
        #expect(exercises.contains { $0.name == "Ejercicio viejo" && $0.isArchived })
        #expect(templates.count == 1)
        #expect(templates[0].orderedExerciseItems.first?.initialSetCount == 2)
        #expect(sessions.count == 1)
        #expect(sessions[0].orderedEntries[0].orderedSets[0].weight == 82.5)
        #expect(sessions[0].isActive == false)
    }

    /// Import is the one path that could otherwise write a "completed but
    /// empty" set directly into history without ever going through
    /// `WorkoutSessionService.finish`'s cleanup or the active-workout
    /// toggle's guard — `validate` must catch it itself.
    @Test func backupWithACompletedButEmptySetIsRejected() throws {
        let exercise = ExerciseDTO(id: UUID(), name: "Press banca", muscleGroup: nil, isArchived: false, createdAt: Date())
        let emptyCompletedSet = SetEntryDTO(id: UUID(), order: 0, weight: nil, reps: 0, isCompleted: true)
        let entry = ExerciseEntryDTO(id: UUID(), order: 0, exerciseID: exercise.id, sets: [emptyCompletedSet])
        let session = WorkoutSessionDTO(
            id: UUID(),
            templateName: "Push A",
            sourceTemplateID: nil,
            date: Date(),
            notes: nil,
            isActive: false,
            entries: [entry]
        )
        let dto = BackupDTO(version: BackupDTO.currentVersion, exercises: [exercise], templates: [], sessions: [session])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)

        #expect(throws: AppGymError.self) {
            try BackupService.validate(data)
        }
    }

    @Test func invalidBackupImportDoesNotCorruptExistingStorage() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        try? context.save()

        let badDTO = BackupDTO(
            version: BackupDTO.currentVersion,
            exercises: [],
            templates: [
                WorkoutTemplateDTO(
                    id: UUID(),
                    name: "Roto",
                    createdAt: Date(),
                    items: [TemplateExerciseItemDTO(id: UUID(), order: 0, initialSetCount: 3, exerciseID: UUID())]
                )
            ],
            sessions: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let badData = try encoder.encode(badDTO)

        #expect(throws: AppGymError.self) {
            try BackupService.importData(badData, context: context)
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(exercises.count == 1)
        #expect(exercises[0].name == "Press banca")
        #expect(templates.count == 1)
        #expect(templates[0].name == "Push A")
    }

    @Test func malformedJSONIsRejectedWithoutTouchingStorage() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        try? context.save()

        let garbage = "no soy JSON".data(using: .utf8)!
        #expect(throws: AppGymError.self) {
            try BackupService.importData(garbage, context: context)
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
    }

    /// Backup roundtrip is meant to preserve functional state exactly,
    /// including a session still in progress: it must come back active, with
    /// its completed and uncompleted sets intact — not silently finished.
    @Test func activeSessionRoundtripsAsActiveWithPendingAndCompletedSetsPreserved() throws {
        let sourceContext = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        sourceContext.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 3)], context: sourceContext)
        let session = try WorkoutSessionService.startSession(from: template, context: sourceContext)
        let entry = session.orderedEntries[0]
        TestSupport.markSet(entry, at: 0, weight: 82.5, reps: 8, completed: true)
        TestSupport.markSet(entry, at: 1, weight: 80, reps: 6, completed: false) // still pending
        // set index 2 left completely untouched (prepopulated only)
        try sourceContext.save()

        let sessionID = session.id
        let data = try BackupService.exportData(context: sourceContext)

        let destinationContext = TestSupport.makeContext()
        try BackupService.importData(data, context: destinationContext)

        let sessions = try destinationContext.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1)
        let restored = try #require(sessions.first)
        #expect(restored.id == sessionID)
        #expect(restored.isActive == true)
        #expect(try WorkoutSessionService.activeSession(context: destinationContext)?.id == sessionID)

        let restoredSets = restored.orderedEntries[0].orderedSets
        #expect(restoredSets.count == 3)
        #expect(restoredSets[0].weight == 82.5)
        #expect(restoredSets[0].reps == 8)
        #expect(restoredSets[0].isCompleted == true)
        #expect(restoredSets[1].weight == 80)
        #expect(restoredSets[1].reps == 6)
        #expect(restoredSets[1].isCompleted == false)
        #expect(restoredSets[2].isCompleted == false)
    }

    @Test func backupWithNoActiveSessionImportsCleanly() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: context)

        let data = try BackupService.exportData(context: context)
        let dto = try BackupService.validate(data)
        #expect(dto.sessions.allSatisfy { !$0.isActive })

        let destinationContext = TestSupport.makeContext()
        try BackupService.importData(data, context: destinationContext)
        #expect(try WorkoutSessionService.activeSession(context: destinationContext) == nil)
    }

    /// The single-active-session invariant must hold for imported data too:
    /// a backup can describe at most one active session.
    @Test func backupWithMoreThanOneActiveSessionIsRejected() throws {
        let exercise = ExerciseDTO(id: UUID(), name: "Press banca", muscleGroup: nil, isArchived: false, createdAt: Date())
        func activeSession() -> WorkoutSessionDTO {
            WorkoutSessionDTO(
                id: UUID(),
                templateName: "Push A",
                sourceTemplateID: nil,
                date: Date(),
                notes: nil,
                isActive: true,
                entries: []
            )
        }
        let dto = BackupDTO(
            version: BackupDTO.currentVersion,
            exercises: [exercise],
            templates: [],
            sessions: [activeSession(), activeSession()]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)

        #expect(throws: AppGymError.self) {
            try BackupService.validate(data)
        }

        // And the rejection must happen before any store mutation.
        let context = TestSupport.makeContext()
        let preexisting = Exercise(name: "Ya existente")
        context.insert(preexisting)
        try context.save()

        #expect(throws: AppGymError.self) {
            try BackupService.importData(data, context: context)
        }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
        #expect(exercises[0].name == "Ya existente")
    }

    @Test func backupWithExactlyOneActiveSessionValidates() throws {
        let exercise = ExerciseDTO(id: UUID(), name: "Press banca", muscleGroup: nil, isArchived: false, createdAt: Date())
        let session = WorkoutSessionDTO(
            id: UUID(),
            templateName: "Push A",
            sourceTemplateID: nil,
            date: Date(),
            notes: nil,
            isActive: true,
            entries: []
        )
        let dto = BackupDTO(version: BackupDTO.currentVersion, exercises: [exercise], templates: [], sessions: [session])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)

        let validated = try BackupService.validate(data)
        #expect(validated.sessions.count == 1)
        #expect(validated.sessions[0].isActive == true)
    }
}
