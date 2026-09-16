import Foundation
import SwiftData

/// Computes personal-record status from every completed set ever logged,
/// including ones in the session currently in progress — not just finished
/// history. PRs are derived, never stored, so they always reflect the
/// current state of the store, and a genuinely heavier set shows the trophy
/// the moment it's marked completed rather than only after "Finish" is tapped.
public enum PersonalRecordCalculator {
    @MainActor
    public static func maxCompletedWeight(for exercise: Exercise, context: ModelContext) -> Double? {
        let descriptor = FetchDescriptor<WorkoutSession>()
        guard let sessions = try? context.fetch(descriptor) else { return nil }
        let weights = sessions
            .flatMap { $0.entries }
            .filter { $0.exercise?.id == exercise.id }
            .flatMap { $0.sets.filter(\.isCompleted).compactMap(\.weight) }
        return weights.max()
    }

    @MainActor
    public static func isPersonalRecord(_ set: SetEntry, exercise: Exercise, context: ModelContext) -> Bool {
        guard set.isCompleted, let weight = set.weight else { return false }
        guard let maxWeight = maxCompletedWeight(for: exercise, context: context) else { return false }
        return weight == maxWeight
    }
}
