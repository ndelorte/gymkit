import Foundation
import SwiftData
import Testing
@testable import AppGymKit

@MainActor
struct PersonalRecordAndProgressTests {

    @Test func prIsDetectedOnTheHeaviestCompletedSet() throws {
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
        let secondEntry = second.orderedEntries[0]
        TestSupport.markSet(secondEntry, at: 0, weight: 82.5, reps: 8, completed: true)
        TestSupport.markSet(secondEntry, at: 1, weight: 82.5, reps: 7, completed: true)
        TestSupport.markSet(secondEntry, at: 2, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(second, context: context)

        #expect(PersonalRecordCalculator.maxCompletedWeight(for: exercise, context: context) == 82.5)

        let heaviestSet = second.orderedEntries[0].orderedSets[0]
        #expect(PersonalRecordCalculator.isPersonalRecord(heaviestSet, exercise: exercise, context: context))

        let nonPRSet = second.orderedEntries[0].orderedSets[2]
        #expect(!PersonalRecordCalculator.isPersonalRecord(nonPRSet, exercise: exercise, context: context))
    }

    /// A genuinely heavier set must show as a PR the moment it's marked
    /// completed, not only after the session is finished — otherwise the
    /// live trophy in the active-workout screen would never fire for an
    /// actual new record, only for ties with old history.
    @Test func prIsDetectedLiveDuringAnActiveSessionNotOnlyAfterFinishing() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)

        let first = try WorkoutSessionService.startSession(from: template, context: context)
        TestSupport.markSet(first.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(first, context: context)

        let second = try WorkoutSessionService.startSession(from: template, context: context)
        let liveSet = second.orderedEntries[0].orderedSets[0]
        TestSupport.markSet(second.orderedEntries[0], at: 0, weight: 90, reps: 5, completed: true)

        // Session is still active — not finished — yet this is already the heaviest set ever.
        #expect(second.isActive)
        #expect(PersonalRecordCalculator.maxCompletedWeight(for: exercise, context: context) == 90)
        #expect(PersonalRecordCalculator.isPersonalRecord(liveSet, exercise: exercise, context: context))
    }

    @Test func exerciseProgressChartHasOnePointPerSessionInChronologicalOrder() throws {
        let context = TestSupport.makeContext()
        let exercise = Exercise(name: "Press banca")
        context.insert(exercise)
        let template = TestSupport.makeTemplate(name: "Push A", exercises: [(exercise, 1)], context: context)

        let first = try WorkoutSessionService.startSession(from: template, context: context)
        first.date = Date(timeIntervalSince1970: 1000)
        TestSupport.markSet(first.orderedEntries[0], at: 0, weight: 80, reps: 8, completed: true)
        try WorkoutSessionService.finish(first, context: context)

        let second = try WorkoutSessionService.startSession(from: template, context: context)
        second.date = Date(timeIntervalSince1970: 2000)
        TestSupport.markSet(second.orderedEntries[0], at: 0, weight: 82.5, reps: 8, completed: true)
        try WorkoutSessionService.finish(second, context: context)
        try? context.save()

        let points = ExerciseProgress.chartPoints(for: exercise, context: context)
        #expect(points.count == 2)
        #expect(points[0].maxWeight == 80)
        #expect(points[1].maxWeight == 82.5)
        #expect(points[0].date < points[1].date)
        #expect(ExerciseProgress.maxWeight(for: exercise, context: context) == 82.5)
        #expect(ExerciseProgress.latestSession(for: exercise, context: context)?.id == second.id)
    }
}
