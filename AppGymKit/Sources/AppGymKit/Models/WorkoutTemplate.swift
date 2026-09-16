import Foundation
import SwiftData

@Model
public final class WorkoutTemplate {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TemplateExerciseItem.template)
    public var exerciseItems: [TemplateExerciseItem]

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        exerciseItems: [TemplateExerciseItem] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.exerciseItems = exerciseItems
    }

    /// Exercise items in display order. Order is authoritative via `order`, not array position.
    public var orderedExerciseItems: [TemplateExerciseItem] {
        exerciseItems.sorted { $0.order < $1.order }
    }
}

@Model
public final class TemplateExerciseItem {
    @Attribute(.unique) public var id: UUID
    public var order: Int
    public var initialSetCount: Int
    public var exercise: Exercise?
    public var template: WorkoutTemplate?

    public init(
        id: UUID = UUID(),
        order: Int,
        initialSetCount: Int,
        exercise: Exercise
    ) {
        self.id = id
        self.order = order
        self.initialSetCount = initialSetCount
        self.exercise = exercise
    }
}
