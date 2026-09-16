import Foundation
import SwiftData

/// Prevents accidentally creating two active exercises that are visually
/// indistinguishable (same name, trimmed, case-insensitive). No database
/// constraint — just a product rule applied at the one place exercises get
/// created, since custom-exercise creation is the only path that can
/// introduce a duplicate.
public enum ExerciseCreation {
    public enum Outcome: Equatable {
        /// A brand-new exercise was created.
        case created
        /// An archived exercise with the same name already existed and was
        /// reactivated instead of creating a second, indistinguishable one.
        case reactivatedArchived
        /// An active exercise with the same name already exists — nothing
        /// was created; the caller should tell the user instead.
        case alreadyActive
    }

    @MainActor
    public static func createIfNeeded(
        name: String,
        muscleGroup: String?,
        context: ModelContext
    ) throws -> (exercise: Exercise, outcome: Outcome) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroup = muscleGroup?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedGroup = (trimmedGroup?.isEmpty ?? true) ? nil : trimmedGroup

        let all = try context.fetch(FetchDescriptor<Exercise>())
        let matchesName: (Exercise) -> Bool = {
            $0.name.compare(trimmedName, options: .caseInsensitive) == .orderedSame
        }

        if let activeMatch = all.first(where: { !$0.isArchived && matchesName($0) }) {
            return (activeMatch, .alreadyActive)
        }

        if let archivedMatch = all.first(where: { $0.isArchived && matchesName($0) }) {
            archivedMatch.isArchived = false
            try context.save()
            return (archivedMatch, .reactivatedArchived)
        }

        let exercise = Exercise(name: trimmedName, muscleGroup: normalizedGroup)
        context.insert(exercise)
        try context.save()
        return (exercise, .created)
    }
}
