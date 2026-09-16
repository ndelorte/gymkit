import Foundation
import SwiftData

/// Owns the two invariants around session lifecycle:
/// - at most one active `WorkoutSession` at a time;
/// - finishing a session discards uncompleted (pre-populated but untouched) sets,
///   so only what actually happened is preserved in history.
public enum WorkoutSessionService {
    @MainActor
    public static func activeSession(context: ModelContext) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.isActive })
        return (try? context.fetch(descriptor))?.first
    }

    /// Starts a new session snapshotted from `template`. Each exercise's sets are
    /// pre-populated (not completed) from the most recent completed performance
    /// of that exercise, when one exists; otherwise sets start empty.
    @discardableResult
    @MainActor
    public static func startSession(from template: WorkoutTemplate, context: ModelContext) throws -> WorkoutSession {
        guard activeSession(context: context) == nil else {
            throw AppGymError.activeSessionAlreadyExists
        }

        let session = WorkoutSession(
            templateName: template.name,
            sourceTemplateID: template.id,
            date: Date(),
            isActive: true
        )

        for item in template.orderedExerciseItems {
            guard let exercise = item.exercise else { continue }
            let entry = ExerciseEntry(order: item.order, exercise: exercise)

            let previous = PreviousSessionFinder.mostRecentCompletedEntry(for: exercise, context: context)
            let previousSets = previous?.entry.orderedSets ?? []

            let setCount = max(item.initialSetCount, 1)
            for index in 0..<setCount {
                let previousSet = index < previousSets.count ? previousSets[index] : nil
                entry.sets.append(SetEntry(
                    order: index,
                    weight: previousSet?.weight,
                    reps: previousSet?.reps ?? 0,
                    isCompleted: false
                ))
            }
            session.entries.append(entry)
        }

        context.insert(session)
        try context.save()
        return session
    }

    /// Finishes `session`: removes any set never explicitly marked completed,
    /// then marks the session completed. Safe to call repeatedly.
    @MainActor
    public static func finish(_ session: WorkoutSession, context: ModelContext) throws {
        guard session.isActive else { throw AppGymError.sessionNotActive }

        for entry in session.entries {
            let uncompleted = entry.sets.filter { !$0.isCompleted }
            for set in uncompleted {
                entry.sets.removeAll { $0.id == set.id }
                context.delete(set)
            }
        }
        session.isActive = false
        try context.save()
    }
}
