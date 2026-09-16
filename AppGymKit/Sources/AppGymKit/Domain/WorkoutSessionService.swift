import Foundation
import SwiftData

/// Owns the two invariants around session lifecycle:
/// - at most one active `WorkoutSession` at a time;
/// - finishing a session discards uncompleted (pre-populated but untouched) sets,
///   so only what actually happened is preserved in history.
public enum WorkoutSessionService {
    /// A fetch failure here must not be read as "no active session" — that
    /// would let `startSession` silently create a second one. Propagate it.
    @MainActor
    public static func activeSession(context: ModelContext) throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.isActive })
        return try context.fetch(descriptor).first
    }

    /// Starts a new session snapshotted from `template`. Each exercise's sets are
    /// pre-populated (not completed) from the most recent completed performance
    /// of that exercise, when one exists; otherwise sets start empty.
    @discardableResult
    @MainActor
    public static func startSession(from template: WorkoutTemplate, context: ModelContext) throws -> WorkoutSession {
        guard try activeSession(context: context) == nil else {
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

    /// Finishes `session`: removes any set never explicitly marked completed
    /// (or marked completed but recording nothing — see
    /// `SetEntry.hasRecordedPerformance`), then removes any exercise left
    /// with zero sets as a result, so a finished session represents only
    /// what was actually done — not exercises that were added but skipped.
    /// Marks the session completed. Safe to call repeatedly.
    @MainActor
    public static func finish(_ session: WorkoutSession, context: ModelContext) throws {
        guard session.isActive else { throw AppGymError.sessionNotActive }

        for entry in session.entries {
            let notPerformed = entry.sets.filter { !$0.isCompleted || !$0.hasRecordedPerformance }
            for set in notPerformed {
                entry.sets.removeAll { $0.id == set.id }
                context.delete(set)
            }
        }

        let skippedExercises = session.entries.filter { $0.sets.isEmpty }
        for entry in skippedExercises {
            session.entries.removeAll { $0.id == entry.id }
            context.delete(entry)
        }

        session.isActive = false
        try context.save()
    }
}
