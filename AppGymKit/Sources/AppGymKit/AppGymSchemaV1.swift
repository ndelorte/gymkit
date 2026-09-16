import Foundation
import SwiftData

/// The current (and, so far, only) schema version. Wrapping the model list
/// in a `VersionedSchema` — instead of handing `Schema` a bare array of
/// model types — is what lets a future `AppGymSchemaV2` be introduced
/// through `AppGymMigrationPlan` without inventing a migration story from
/// scratch under time pressure. Do not add a `V2` here speculatively; add it
/// only when a real model change needs one, per `AppGymMigrationPlan`'s doc.
public enum AppGymSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExerciseItem.self,
            WorkoutSession.self,
            ExerciseEntry.self,
            SetEntry.self
        ]
    }
}

/// Registers every schema version AppGym has ever shipped, plus the stages
/// needed to migrate between them.
///
/// There is only one version today, so `stages` is empty — SwiftData opens
/// an existing v1 store directly, no migration runs. When a real schema
/// change is needed:
///
/// 1. Add `AppGymSchemaV2: VersionedSchema` (bump `versionIdentifier`,
///    list the new model set — reuse unchanged `@Model` types from
///    `AppGymSchemaV1` where possible via a typealias so they aren't
///    duplicated).
/// 2. Append `AppGymSchemaV2.self` to `schemas` below.
/// 3. Add a `.lightweight(fromVersion:toVersion:)` stage if the change is
///    additive/renames only, or `.custom(fromVersion:toVersion:willMigrate:didMigrate:)`
///    if data needs transforming — to `stages`.
///
/// Existing installs then upgrade in place the next time the app launches;
/// nothing about `AppGymSchema.makeContainer` needs to change.
public enum AppGymMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [AppGymSchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []
    }
}
