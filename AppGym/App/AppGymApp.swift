import SwiftUI
import SwiftData
import AppGymKit

@main
struct AppGymApp: App {
    let container: ModelContainer

    init() {
        if ProcessInfo.processInfo.arguments.contains("-UITestReset") {
            AppGymSchema.deleteOnDiskStore()
        }
        let container = AppGymSchema.makeContainer()
        self.container = container
        ExerciseLibrarySeeder.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
