import Foundation
import SwiftData

public struct ExerciseChartPoint: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let maxWeight: Double

    public init(id: UUID, date: Date, maxWeight: Double) {
        self.id = id
        self.date = date
        self.maxWeight = maxWeight
    }
}

/// Aggregates everything the Exercise detail screen needs: latest session,
/// max historical weight, chronological history, and chart points.
public enum ExerciseProgress {
    @MainActor
    public static func latestSession(for exercise: Exercise, context: ModelContext) -> WorkoutSession? {
        PreviousSessionFinder.mostRecentCompletedEntry(for: exercise, context: context)?.session
    }

    @MainActor
    public static func maxWeight(for exercise: Exercise, context: ModelContext) -> Double? {
        PersonalRecordCalculator.maxCompletedWeight(for: exercise, context: context)
    }

    /// Chronological (oldest first), one point per session with at least one
    /// completed weighted set, for the progress chart.
    @MainActor
    public static func chartPoints(for exercise: Exercise, context: ModelContext) -> [ExerciseChartPoint] {
        let history = PreviousSessionFinder.history(for: exercise, context: context)
        let points: [ExerciseChartPoint] = history.compactMap { session, entry in
            let completedWeights = entry.sets.filter(\.isCompleted).compactMap(\.weight)
            guard let maxWeight = completedWeights.max() else { return nil }
            return ExerciseChartPoint(id: session.id, date: session.date, maxWeight: maxWeight)
        }
        return points.sorted { $0.date < $1.date }
    }
}
