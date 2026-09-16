import Foundation
import SwiftData

public enum AppGymSchema {
    public static let models: [any PersistentModel.Type] = [
        Exercise.self,
        WorkoutTemplate.self,
        TemplateExerciseItem.self,
        WorkoutSession.self,
        ExerciseEntry.self,
        SetEntry.self
    ]

    public static var schema: Schema {
        Schema(models)
    }

    /// Fixed, well-known store location (rather than SwiftData's default) so
    /// UI tests can deterministically wipe it to start from a clean slate.
    public static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "AppGym.sqlite")
    }

    /// Creates the app's `ModelContainer`. `inMemory` is used by tests and previews
    /// so they never touch the real on-disk store.
    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(url: defaultStoreURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear el almacén de datos: \(error)")
        }
    }

    /// Deletes the on-disk store (including WAL/SHM sidecar files). Used only
    /// by UI tests to guarantee a clean starting state before the first launch.
    public static func deleteOnDiskStore() {
        let base = defaultStoreURL
        let suffixes = ["", "-wal", "-shm"]
        for suffix in suffixes {
            let url = URL(fileURLWithPath: base.path + suffix)
            try? FileManager.default.removeItem(at: url)
        }
    }
}
