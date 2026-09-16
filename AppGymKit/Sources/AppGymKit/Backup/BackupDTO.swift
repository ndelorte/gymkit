import Foundation

public struct BackupDTO: Codable {
    public var version: Int
    public var exercises: [ExerciseDTO]
    public var templates: [WorkoutTemplateDTO]
    public var sessions: [WorkoutSessionDTO]

    public init(version: Int, exercises: [ExerciseDTO], templates: [WorkoutTemplateDTO], sessions: [WorkoutSessionDTO]) {
        self.version = version
        self.exercises = exercises
        self.templates = templates
        self.sessions = sessions
    }

    public static let currentVersion = 1
}

public struct ExerciseDTO: Codable {
    public var id: UUID
    public var name: String
    public var muscleGroup: String?
    public var isArchived: Bool
    public var createdAt: Date

    public init(id: UUID, name: String, muscleGroup: String?, isArchived: Bool, createdAt: Date) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

public struct WorkoutTemplateDTO: Codable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var items: [TemplateExerciseItemDTO]

    public init(id: UUID, name: String, createdAt: Date, items: [TemplateExerciseItemDTO]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = items
    }
}

public struct TemplateExerciseItemDTO: Codable {
    public var id: UUID
    public var order: Int
    public var initialSetCount: Int
    public var exerciseID: UUID

    public init(id: UUID, order: Int, initialSetCount: Int, exerciseID: UUID) {
        self.id = id
        self.order = order
        self.initialSetCount = initialSetCount
        self.exerciseID = exerciseID
    }
}

public struct WorkoutSessionDTO: Codable {
    public var id: UUID
    public var templateName: String
    public var sourceTemplateID: UUID?
    public var date: Date
    public var notes: String?
    public var isActive: Bool
    public var entries: [ExerciseEntryDTO]

    public init(id: UUID, templateName: String, sourceTemplateID: UUID?, date: Date, notes: String?, isActive: Bool, entries: [ExerciseEntryDTO]) {
        self.id = id
        self.templateName = templateName
        self.sourceTemplateID = sourceTemplateID
        self.date = date
        self.notes = notes
        self.isActive = isActive
        self.entries = entries
    }
}

public struct ExerciseEntryDTO: Codable {
    public var id: UUID
    public var order: Int
    public var exerciseID: UUID
    public var sets: [SetEntryDTO]

    public init(id: UUID, order: Int, exerciseID: UUID, sets: [SetEntryDTO]) {
        self.id = id
        self.order = order
        self.exerciseID = exerciseID
        self.sets = sets
    }
}

public struct SetEntryDTO: Codable {
    public var id: UUID
    public var order: Int
    public var weight: Double?
    public var reps: Int
    public var isCompleted: Bool

    public init(id: UUID, order: Int, weight: Double?, reps: Int, isCompleted: Bool) {
        self.id = id
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }
}
