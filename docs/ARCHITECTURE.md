# Architecture

## Split: AppGymKit (logic) vs AppGym (UI)

All persistence and business rules live in the `AppGymKit` Swift package, kept
separate from the SwiftUI app target so the domain logic has a fast,
simulator-free test suite (`cd AppGymKit && swift test`). The app target is
intentionally thin — views bind to SwiftData `@Query`/`@Bindable` models and
call into `AppGymKit`'s domain services for anything with a rule attached to
it (starting/finishing a session, previous-value lookup, PR detection,
backup). There is no separate MVVM layer: SwiftData models plus a handful of
stateless domain enums is enough for an app this size, and an extra
ViewModel layer would just be indirection with no independent behavior to
test.

## Domain model

```
WorkoutTemplate ──< TemplateExerciseItem >── Exercise
                                                 ▲
WorkoutSession ──< ExerciseEntry >── SetEntry    │
                        └───────────────────────-┘
```

- **Exercise**: `name`, optional `muscleGroup`, `isArchived`. Never
  hard-deleted — archiving is the only removal path, so historical
  `ExerciseEntry` references stay valid forever.
- **WorkoutTemplate** / **TemplateExerciseItem**: a reusable, editable plan.
  Each item pairs an `Exercise` with an `order` and an `initialSetCount`.
- **WorkoutSession**: a point-in-time record. Stores `templateName` and
  `sourceTemplateID` as a *snapshot* — never re-reads the live template — so
  renaming, editing or deleting a template can never alter history. Has
  `isActive`; exactly one session may be active at a time
  (`WorkoutSessionService.startSession` throws `activeSessionAlreadyExists`
  otherwise).
- **ExerciseEntry** / **SetEntry**: what actually happened. `SetEntry.weight`
  is `Double?` (decimal kg, optional so an empty/never-touched set is
  representable), `reps: Int`, `isCompleted: Bool`.

## Key invariants (and where they're enforced)

1. **Template edits never mutate history.** `WorkoutSession` snapshots the
   template's name and copies exercises/sets into its own `ExerciseEntry`/
   `SetEntry` graph at start time; nothing in a finished session reads back
   through to `WorkoutTemplate`. Covered by
   `WorkoutSessionServiceTests.changingTemplateDoesNotMutateHistoricalSession`.
2. **At most one active session.** Enforced in
   `WorkoutSessionService.startSession` by fetching for an existing
   `isActive` session first — this is the *only* place that invariant is
   enforced, so anything that constructs a `WorkoutSession` directly (e.g.
   `BackupService.importData`) must not be able to mark it active.
3. **Pre-populated sets are not "performed" until explicitly completed —
   and "completed" itself requires recording something.**
   `WorkoutSessionService.finish` deletes every `SetEntry` that's either
   still `isCompleted == false`, or `isCompleted == true` but
   `hasRecordedPerformance == false` (no weight *and* zero reps — see
   `SetEntry.hasRecordedPerformance`), before flipping the session to
   completed. A bodyweight set (`weight == nil`, `reps > 0`) is a real
   performance and survives; a blank set that got marked completed some
   other way (a UI bug, a future bad backup) does not. Any `ExerciseEntry`
   left with zero sets afterward — an exercise that was added/planned but
   never actually performed — is removed too, so a finished session's
   exercise list reflects only what was done. The active-workout completion
   toggle (`SetRowView`) also refuses to mark an empty set completed in the
   first place; `finish` is the authoritative backstop regardless.
4. **Previous-session memory.** `PreviousSessionFinder` walks completed
   sessions newest-first and returns the first `ExerciseEntry` matching a
   given `Exercise`. `WorkoutSessionService.startSession` uses this to
   pre-fill (but not pre-complete) new sets.
5. **PRs are derived, never stored.** `PersonalRecordCalculator` computes the
   max completed weight for an exercise on demand across *every* session,
   active or finished — not just history — so a genuinely heavier set shows
   the trophy the moment it's marked completed, not only after "Finish" is
   tapped. A set "is a PR" if its weight equals that max. Recomputing on
   demand means editing a past session automatically updates which set is
   flagged.
6. **Archived exercises stay visible in history.** Archiving only sets a
   flag; `PreviousSessionFinder`/history queries don't filter on it.

## Persistence

SwiftData, one on-disk SQLite store at a fixed path
(`AppGymSchema.defaultStoreURL`, under Application Support) so autosave and
crash/relaunch recovery are just "read the store back" — there is no
separate journal or draft state for an active session. Every mutation in the
UI layer calls `context.save()` immediately after changing a model; this is
what satisfies "no manual Save button, survives termination."

`AppGymSchema.deleteOnDiskStore()` exists solely so the UI test can start
from a clean store — the app itself never calls it outside of the
`-UITestReset` launch argument check in `AppGymApp.init()`.

## Backup

`BackupService` exports/imports a versioned JSON document
(`AppGymKit/Sources/AppGymKit/Backup/BackupDTO.swift`), and the roundtrip is
meant to be a full functional restore — including a session still in
progress, not just finished history. `exportData` uses real `try` (not
`try? … ?? []`) on every fetch, so a read failure fails the export outright
instead of silently producing a backup that's missing whatever didn't read.

Import is two-phase: `validate(_:)` fully decodes and checks referential
integrity (every exercise ID a template/session refers to must exist, no
duplicate IDs, non-negative reps/weights, no set marked completed with
neither weight nor reps recorded — mirrors `SetEntry.hasRecordedPerformance`,
since import is the one path that writes directly into history without ever
going through `WorkoutSessionService.finish`'s cleanup — and **at most one
session with `isActive == true`**) with **no store access at all**; only if
that succeeds does `importData` touch the `ModelContext`, and if anything
throws after that point it calls `context.rollback()` before rethrowing, so
a failed import cannot leave the store partially overwritten.

`isActive` is restored faithfully from the backup (including its completed
and still-pending sets) rather than forced to `false`. This can't reopen the
single-active-session invariant: `validate` already rejects a file
describing more than one active session, and import always replaces the
entire store (existing sessions are deleted before the new ones are
inserted), so there's never a pre-existing active session left over to
collide with the restored one. The invariant itself is still enforced in
exactly one place, `WorkoutSessionService.startSession` — import just can't
violate it as a side effect anymore.

## Persistence error handling

A `context.save()` failure must never let the UI act as if the operation
succeeded (a sheet dismissing, a delete appearing to go through). Every
screen routes its saves through one small, reusable pattern in
`AppGym/Views/Shared/PersistenceResult.swift`:

- `PersistenceResult.save(_ context:)` attempts the save; on failure it rolls
  back the context (so `@Query` results reflect what's actually on disk, not
  an optimistic in-memory change that never persisted) and returns a message
  string, or `nil` on success.
- `.persistenceErrorAlert(_:)` is a `View` extension that turns a
  `@State private var saveError: String?` into a standard alert.

A screen that dismisses on save (template creation/editing, deleting a
historical session) only calls `dismiss()` when `PersistenceResult.save`
returns `nil`; on failure it sets `saveError` and stays open. This isn't a
new architecture layer — it's two small, reusable pieces used the same way
everywhere a `try? context.save()` used to be.

`ExerciseLibrarySeeder` is the one exception: it runs at app launch, before
any UI exists to show an alert. A read/write failure there
`assertionFailure`s (traps in debug builds, so it's caught in development;
a no-op in release, since the worst case is an empty exercise library the
user can still populate by hand) rather than being silently swallowed.

## Duplicate exercise names

`ExerciseCreation.createIfNeeded` (`AppGymKit/Sources/AppGymKit/Domain/ExerciseCreation.swift`)
is the one place a custom exercise gets created, and it applies a simple
product rule instead of a database constraint: names are compared trimmed
and case-insensitively. If an *active* exercise with that name already
exists, nothing new is created and the caller is told (the create form stays
open so the user can rename or cancel). If only an *archived* one matches,
it's reactivated instead of creating a second, visually-identical exercise.

## Schema versioning and migration readiness

`AppGymSchemaV1` wraps the model list in a `VersionedSchema` (rather than
handing `Schema` a bare array of model types), and `AppGymMigrationPlan`
registers it with an empty `stages` array — there's only ever been one
schema version, so there's nothing to migrate *from* yet. `AppGymSchema.
makeContainer` passes both into `ModelContainer(for:migrationPlan:configurations:)`.

This is scaffolding, not a real migration: adding it didn't change the
on-disk format at all (verified by opening a store created before this
change with the new code — same data, no migration ran, nothing lost).
What it buys is a defined place to put the next schema change instead of
improvising one under time pressure. When a real change is needed:

1. Add `AppGymSchemaV2: VersionedSchema` with the new model set.
2. Append it to `AppGymMigrationPlan.schemas`.
3. Add a `.lightweight` or `.custom` `MigrationStage` from v1 to v2.

`AppGymSchema.makeContainer`'s `fatalError` remains a last resort for a
genuinely unreadable store (disk corruption, a future incompatible format on
disk) — normal schema upgrades go through the migration plan and never reach
it.

## Why no separate "active session" state machine

The active workout screen is just `EntrenarView` querying for a
`WorkoutSession` where `isActive == true` and showing `ActiveWorkoutView` if
one exists, `HomeView` otherwise. Recovering after a relaunch is not a
special code path — it's the same query returning the same row it would on
any other launch.
