import Foundation
import SwiftData

public enum AppGymSchema {
    public static let models: [any PersistentModel.Type] = AppGymSchemaV1.models

    /// Built from `AppGymSchemaV1`, not a bare model array — see
    /// `AppGymSchemaV1`/`AppGymMigrationPlan` for why, and how a future
    /// schema version gets added.
    public static var schema: Schema {
        Schema(versionedSchema: AppGymSchemaV1.self)
    }

    /// Fixed, well-known store location (rather than SwiftData's default) so
    /// UI tests can deterministically wipe it to start from a clean slate.
    public static var defaultStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "AppGym.sqlite")
    }

    /// Creates the app's `ModelContainer`. `inMemory` is used by tests and previews
    /// so they never touch the real on-disk store.
    ///
    /// The `fatalError` below is a last resort for a genuinely unreadable
    /// store (disk corruption, an on-disk file from some future
    /// incompatible version) — it is not the migration strategy. A normal
    /// schema upgrade runs through `AppGymMigrationPlan` via the
    /// `migrationPlan:` parameter and never reaches this catch block, and no
    /// existing data is destroyed to get there.
    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: defaultStoreURL)
        do {
            return try ModelContainer(for: schema, migrationPlan: AppGymMigrationPlan.self, configurations: [configuration])
        } catch {
            fatalError("No se pudo crear ni migrar el almacén de datos: \(error)")
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
