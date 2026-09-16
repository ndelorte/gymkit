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
}
