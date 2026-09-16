import Foundation
import SwiftData

/// Locates prior completed performance for an exercise, used to preload
/// "previous workout memory" when starting a new session.
public enum PreviousSessionFinder {
    /// Most recent completed session/entry pair containing `exercise`, excluding
    /// `excludingSessionID` (typically the session currently being built).
    @MainActor
    public static func mostRecentCompletedEntry(
        for exercise: Exercise,
        excludingSessionID: UUID? = nil,
        context: ModelContext
    ) -> (session: WorkoutSession, entry: ExerciseEntry)? {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? context.fetch(descriptor) else { return nil }

        for session in sessions {
            if let excludingSessionID, session.id == excludingSessionID { continue }
            if let entry = session.entries.first(where: { $0.exercise?.id == exercise.id }) {
                return (session, entry)
            }
        }
        return nil
    }

    /// All completed sessions/entries for `exercise`, most recent first.
    @MainActor
    public static func history(
        for exercise: Exercise,
        context: ModelContext
    ) -> [(session: WorkoutSession, entry: ExerciseEntry)] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { !$0.isActive },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? context.fetch(descriptor) else { return [] }

        return sessions.compactMap { session in
            guard let entry = session.entries.first(where: { $0.exercise?.id == exercise.id }) else {
                return nil
            }
            return (session, entry)
        }
    }
}
