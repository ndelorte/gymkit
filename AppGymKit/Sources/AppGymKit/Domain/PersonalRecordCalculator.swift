import Foundation
import SwiftData

/// Computes personal-record status from completed history. PRs are derived,
/// never stored, so they always reflect the current state of history.
public enum PersonalRecordCalculator {
    @MainActor
    public static func maxCompletedWeight(for exercise: Exercise, context: ModelContext) -> Double? {
        let history = PreviousSessionFinder.history(for: exercise, context: context)
        let weights = history.flatMap { $0.entry.sets.filter(\.isCompleted).compactMap(\.weight) }
        return weights.max()
    }

    @MainActor
    public static func isPersonalRecord(_ set: SetEntry, exercise: Exercise, context: ModelContext) -> Bool {
        guard set.isCompleted, let weight = set.weight else { return false }
        guard let maxWeight = maxCompletedWeight(for: exercise, context: context) else { return false }
        return weight == maxWeight
    }
}
