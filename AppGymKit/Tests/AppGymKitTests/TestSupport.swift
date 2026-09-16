import Foundation
import SwiftData
@testable import AppGymKit

@MainActor
enum TestSupport {
    /// Containers must be kept alive for as long as their context is used —
    /// `ModelContext` does not retain its container, so an unretained
    /// container can be deallocated out from under its context.
    private static var retainedContainers: [ModelContainer] = []

    static func makeContext() -> ModelContext {
        let container = AppGymSchema.makeContainer(inMemory: true)
        retainedContainers.append(container)
        return container.mainContext
    }

    @discardableResult
    static func makeTemplate(
        name: String,
        exercises: [(exercise: Exercise, sets: Int)],
        context: ModelContext
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        for (index, entry) in exercises.enumerated() {
            let item = TemplateExerciseItem(order: index, initialSetCount: entry.sets, exercise: entry.exercise)
            item.template = template
            template.exerciseItems.append(item)
        }
        context.insert(template)
        try? context.save()
        return template
    }

    static func markSet(_ entry: ExerciseEntry, at index: Int, weight: Double?, reps: Int, completed: Bool) {
        let sets = entry.orderedSets
        guard index < sets.count else { return }
        sets[index].weight = weight
        sets[index].reps = reps
        sets[index].isCompleted = completed
    }
}
