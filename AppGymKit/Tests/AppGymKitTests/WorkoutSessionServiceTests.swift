import Foundation
import SwiftData
import Testing
@testable import AppGymKit

@MainActor
struct WorkoutSessionServiceTests {

    @Test func onlyOneActiveSessionAllowed() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 3)], context: context)

        _ = try WorkoutSessionService.startSession(from: template, context: context)

        #expect(throws: AppGymError.activeSessionAlreadyExists) {
            try WorkoutSessionService.startSession(from: template, context: context)
        }
    }

    @Test func startingSessionSnapshotsTemplate() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 3)], context: context)

        let session = try WorkoutSessionService.startSession(from: template, context: context)

        #expect(session.isActive)
        #expect(session.templateName == "Push A")
        #expect(session.orderedEntries.count == 1)
        #expect(session.orderedEntries[0].orderedSets.count == 3)
        #expect(session.orderedEntries[0].orderedSets.allSatisfy { !$0.isCompleted })
    }

    @Test func finishingRemovesUncompletedSetsAndKeepsCompletedOnes() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 3)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        let entry = session.orderedEntries[0]

        TestSupport.markSet(entry, at: 0, weight: 80, reps: 8, completed: true)
        TestSupport.markSet(entry, at: 1, weight: 80, reps: 8, completed: true)
        // set index 2 left untouched/uncompleted

        try WorkoutSessionService.finish(session, context: context)

        #expect(session.isActive == false)
        #expect(entry.orderedSets.count == 2)
        #expect(entry.orderedSets.allSatisfy { $0.isCompleted })
    }

    @Test func decimalWeightsRoundtrip() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        let entry = session.orderedEntries[0]

        TestSupport.markSet(entry, at: 0, weight: 82.5, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: context)

        #expect(entry.orderedSets[0].weight == 82.5)
    }

    @Test func changingTemplateDoesNotMutateHistoricalSession() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: context)

        // Mutate the template after the fact.
        template.name = "Push A (renombrado)"
        template.orderedExerciseItems[0].initialSetCount = 5
        try? context.save()

        #expect(session.templateName == "Push A")
        #expect(session.orderedEntries[0].orderedSets.count == 1)
        #expect(session.orderedEntries[0].orderedSets[0].weight == 80)
    }
}
