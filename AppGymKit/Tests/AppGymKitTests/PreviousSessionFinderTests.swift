import Foundation
import SwiftData
import Testing
@testable import AppGymKit

@MainActor
struct PreviousSessionFinderTests {

    @Test func previousSessionPrefillsNextSessionValues() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 3)], context: context)

        let first = try WorkoutSessionService.startSession(from: template, context: context)
        let firstEntry = first.orderedEntries[0]
        TestSupport.markSet(firstEntry, at: 0, weight: 80, reps: 8, completed: true)
        TestSupport.markSet(firstEntry, at: 1, weight: 80, reps: 8, completed: true)
        TestSupport.markSet(firstEntry, at: 2, weight: 80, reps: 7, completed: true)
        try WorkoutSessionService.finish(first, context: context)

        let second = try WorkoutSessionService.startSession(from: template, context: context)
        let secondSets = second.orderedEntries[0].orderedSets

        #expect(secondSets.map(\.weight) == [80, 80, 80])
        #expect(secondSets.map(\.reps) == [8, 8, 7])
        // Pre-populated values must NOT be considered performed.
        #expect(secondSets.allSatisfy { !$0.isCompleted })
    }

    @Test func noPreviousSessionLeavesSetsEmpty() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Sentadilla")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Legs", exercises: [(exercise, 2)], context: context)

        let session = try WorkoutSessionService.startSession(from: template, context: context)
        let sets = session.orderedEntries[0].orderedSets

        #expect(sets.allSatisfy { $0.weight == nil && $0.reps == 0 })
    }

    @Test func archivedExercisesRemainVisibleInHistory() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(session, context: context)

        exercise.isArchived = true
        try? context.save()

        let history = PreviousSessionFinder.history(for: exercise, context: context)
        #expect(history.count == 1)
        #expect(history[0].entry.exercise?.name == "Press banca")
        #expect(history[0].entry.orderedSets[0].weight == 80)
    }
}
