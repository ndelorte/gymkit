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

    /// A set marked completed but recording nothing (no weight, zero reps)
    /// never actually happened — `finish` must drop it exactly like an
    /// untouched uncompleted set, not just ones that were never toggled on.
    @Test func finishRemovesCompletedButEmptySets() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 2)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        let entry = session.orderedEntries[0]

        TestSupport.markSet(entry, at: 0, weight: 80, reps: 8, completed: true)
        // Simulates a bad state reaching the domain layer some other way
        // (backup import, future bug) rather than through the UI guard.
        entry.orderedSets[1].isCompleted = true

        try WorkoutSessionService.finish(session, context: context)

        #expect(entry.orderedSets.count == 1)
        #expect(entry.orderedSets[0].weight == 80)
    }

    /// A bodyweight set (no weight, real reps) is a legitimate performance
    /// and must survive finishing — only "no weight AND zero reps" is empty.
    @Test func finishKeepsCompletedBodyweightSets() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Dominadas")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Pull A", exercises: [(exercise, 1)], context: context)
        let session = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: nil, reps: 10, completed: true)

        try WorkoutSessionService.finish(session, context: context)

        #expect(session.orderedEntries[0].orderedSets.count == 1)
        #expect(session.orderedEntries[0].orderedSets[0].reps == 10)
    }

    /// Finishing a session must drop any exercise nobody actually performed
    /// (added to the plan/session but every set stayed pending), so history
    /// never shows more exercises than were really done.
    @Test func finishRemovesExercisesWithNoPerformedSets() throws {
        let context = TestSupport.makeContext()
        let pressBanca = Exercise(name: "Press banca")
        let pressInclinado = Exercise(name: "Press inclinado")
        let fondos = Exercise(name: "Fondos")
        context.insert(pressBanca)
        context.insert(pressInclinado)
        context.insert(fondos)
        let template = TestSupport.makeTemplate(
            name: "Push A",
            exercises: [(pressBanca, 2), (pressInclinado, 2), (fondos, 2)],
            context: context
        )
        let session = try WorkoutSessionService.startSession(from: template, context: context)

        // Only Press banca and Fondos are actually performed.
        TestSupport.markSet(session.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        TestSupport.markSet(session.orderedEntries[2], at: 0, weight: 40, reps: 10, completed: true)
        // Press inclinado (index 1) is left completely untouched.

        try WorkoutSessionService.finish(session, context: context)

        #expect(session.entries.count == 2)
        #expect(!session.entries.contains { $0.exercise?.name == "Press inclinado" })
        #expect(session.entries.contains { $0.exercise?.name == "Press banca" })
        #expect(session.entries.contains { $0.exercise?.name == "Fondos" })
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
