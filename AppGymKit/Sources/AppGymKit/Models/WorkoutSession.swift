import Foundation
import SwiftData

@Model
public final class WorkoutSession {
    @Attribute(.unique) public var id: UUID
    /// Snapshot of the source template's name at the time the session was started.
    /// Never re-read from the template, so renaming/deleting a template never
    /// changes what a historical session displays.
    public var templateName: String
    /// Weak reference for informational purposes only (e.g. "started from Push A").
    /// Never used to look up live template data for a historical session.
    public var sourceTemplateID: UUID?
    public var date: Date
    public var notes: String?
    public var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.session)
    public var entries: [ExerciseEntry]

    public init(
        id: UUID = UUID(),
        templateName: String,
        sourceTemplateID: UUID? = nil,
        date: Date = Date(),
        notes: String? = nil,
        isActive: Bool = true,
        entries: [ExerciseEntry] = []
    ) {
        self.id = id
        self.templateName = templateName
        self.sourceTemplateID = sourceTemplateID
        self.date = date
        self.notes = notes
        self.isActive = isActive
        self.entries = entries
    }

    public var orderedEntries: [ExerciseEntry] {
        entries.sorted { $0.order < $1.order }
    }
}

@Model
public final class ExerciseEntry {
    @Attribute(.unique) public var id: UUID
    public var order: Int
    public var exercise: Exercise?
    public var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exerciseEntry)
    public var sets: [SetEntry]

    public init(
        id: UUID = UUID(),
        order: Int,
        exercise: Exercise,
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.sets = sets
    }

    public var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }
}

@Model
public final class SetEntry {
    @Attribute(.unique) public var id: UUID
    public var order: Int
    public var weight: Double?
    public var reps: Int
    public var isCompleted: Bool
    public var exerciseEntry: ExerciseEntry?

    public init(
        id: UUID = UUID(),
        order: Int,
        weight: Double? = nil,
        reps: Int = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}
