import SwiftUI
import SwiftData
import AppGymKit

/// The "Entrenar" tab is the app's home. It shows either the quick-start
/// screen (templates + recent workouts) or, when a session is in progress,
/// the active workout — recovered automatically after a relaunch since it's
/// just a query over persisted state, not view-local state.
struct EntrenarView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.isActive })
    private var activeSessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            if let session = activeSessions.first {
                ActiveWorkoutView(session: session)
            } else {
                HomeView()
            }
        }
    }
}
