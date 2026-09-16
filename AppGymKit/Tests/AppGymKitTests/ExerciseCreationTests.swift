import Foundation
import SwiftData
import Testing
@testable import AppGymKit

@MainActor
struct ExerciseCreationTests {

    @Test func createsANewExerciseWhenNameIsUnique() throws {
        let context = TestSupport.makeContext()

        let (exercise, outcome) = try ExerciseCreation.createIfNeeded(name: "Press banca", muscleGroup: "Pecho", context: context)

        #expect(outcome == .created)
        #expect(exercise.name == "Press banca")
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    /// Comparison is trimmed and case-insensitive, so "press banca " and
    /// "Press Banca" are recognized as the same exercise.
    @Test func doesNotCreateADuplicateOfAnActiveExercise() throws {
        let context = TestSupport.makeContext()
        let existing = Exercise(name: "Press banca")
        context.insert(existing)
        try context.save()

        let (exercise, outcome) = try ExerciseCreation.createIfNeeded(name: "  press BANCA  ", muscleGroup: nil, context: context)

        #expect(outcome == .alreadyActive)
        #expect(exercise.id == existing.id)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    @Test func reactivatesAnArchivedExerciseInsteadOfDuplicating() throws {
        let context = TestSupport.makeContext()
        let archived = Exercise(name: "Press banca", isArchived: true)
        context.insert(archived)
        try context.save()

        let (exercise, outcome) = try ExerciseCreation.createIfNeeded(name: "Press banca", muscleGroup: nil, context: context)

        #expect(outcome == .reactivatedArchived)
        #expect(exercise.id == archived.id)
        #expect(exercise.isArchived == false)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).count == 1)
    }

    @Test func trimsNameAndOptionalMuscleGroup() throws {
        let context = TestSupport.makeContext()

        let (exercise, _) = try ExerciseCreation.createIfNeeded(name: "  Sentadilla  ", muscleGroup: "  Piernas  ", context: context)

        #expect(exercise.name == "Sentadilla")
        #expect(exercise.muscleGroup == "Piernas")
    }

    @Test func blankMuscleGroupIsStoredAsNil() throws {
        let context = TestSupport.makeContext()

        let (exercise, _) = try ExerciseCreation.createIfNeeded(name: "Sentadilla", muscleGroup: "   ", context: context)

        #expect(exercise.muscleGroup == nil)
    }
}
