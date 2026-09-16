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
3. **Pre-populated sets are not "performed" until explicitly completed.**
   `WorkoutSessionService.finish` deletes every `SetEntry` still marked
   `isCompleted == false` before flipping the session to completed — so a
   set the user never touched (or unmarked) simply isn't part of history.
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
(`AppGymKit/Sources/AppGymKit/Backup/BackupDTO.swift`). Import is two-phase:
`validate(_:)` fully decodes and checks referential integrity (every
exercise ID a template/session refers to must exist, no duplicate IDs,
non-negative reps/weights) with **no store access at all**; only if that
succeeds does `importData` touch the `ModelContext`, and if anything throws
after that point it calls `context.rollback()` before rethrowing, so a
failed import cannot leave the store partially overwritten. Every imported
session is forced to `isActive = false` regardless of what the backup file
says — restoring a backup must never resurrect a live in-progress session,
since that's the only way the single-active-session invariant could be
bypassed (it's otherwise enforced solely in `WorkoutSessionService.startSession`).

## Why no separate "active session" state machine

The active workout screen is just `EntrenarView` querying for a
`WorkoutSession` where `isActive == true` and showing `ActiveWorkoutView` if
one exists, `HomeView` otherwise. Recovering after a relaunch is not a
special code path — it's the same query returning the same row it would on
any other launch.
