import Foundation
import SwiftData
import Testing
@testable import AppGymKit

@MainActor
struct HistoryEditingTests {

    @Test func editingAHistoricalSessionPersists() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: context)

        let newDate = Date(timeIntervalSince1970: 5000)
        session.date = newDate
        session.notes = "Buena sesión"
        session.orderedEntries[0].orderedSets[0].weight = 85
        session.orderedEntries[0].orderedSets[0].reps = 6
        try context.save()

        let sessionID = session.id
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        let reloaded = try context.fetch(descriptor).first
        #expect(reloaded?.date == newDate)
        #expect(reloaded?.notes == "Buena sesión")
        #expect(reloaded?.orderedEntries[0].orderedSets[0].weight == 85)
        #expect(reloaded?.orderedEntries[0].orderedSets[0].reps == 6)
        #expect(reloaded?.isActive == false)
    }

    @Test func deletingAHistoricalSessionRemovesItAndItsSets() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: context)

        context.delete(session)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<WorkoutSession>())
        let remainingSets = try context.fetch(FetchDescriptor<SetEntry>())
        #expect(remaining.isEmpty)
        #expect(remainingSets.isEmpty)
    }
}
