# Product decisions where the spec was ambiguous

The goal's DOMAIN section lists `WorkoutTemplate` as having "initial set
count" as one property, but the CREATE WORKOUT flow implies each exercise
gets its own count ("define initial number of sets" after adding several
exercises). Modeled it **per exercise** (`TemplateExerciseItem.initialSetCount`)
— a template with a heavy compound lift and an accessory movement
legitimately wants different set counts, and per-exercise is a strict
superset of per-template (set them all equal if that's what you want).

**PR ties.** "Mark a set as PR when it represents the highest historical
completed weight" doesn't say what happens if two sets across history share
the max weight. Implemented as: every completed set whose weight equals the
current historical max is flagged. Simplest rule that matches the letter of
the spec; a future version could restrict it to only the most recent
occurrence if that reads better in practice.

**Adding an exercise mid-session.** Not covered by "previous workout
memory" (which is framed around starting a session from a template). Applied
the same previous-value preload logic when an exercise is added directly
during an active session, since the alternative (blank sets) would be a
worse experience for no stated reason, and it doesn't touch anything
out-of-scope.

**Deleting a historical session's last set / all sets.** Not specified.
Allowed — a `WorkoutSession`/`ExerciseEntry` can end up with zero sets under
editing. No special-cased cleanup; this is deliberately unhandled because
the spec doesn't ask for it and it isn't a state that breaks anything else
(chart/PR/history code all treat "no completed weighted sets" as "no data
point," not an error).

**Backup UI location.** The NAVIGATION section fixes three tabs and
explicitly forbids a fourth (Analytics) but says nothing about where
export/import lives. Placed it behind an "•••" menu on the Ejercicios tab —
it's data-library-adjacent and doesn't warrant a tab or a Home-screen
button given how rarely it's used.

**No ad-hoc (template-less) session start.** The CREATE WORKOUT flow requires
going through a template, and the goal doesn't ask for a "start blank"
option, so `WorkoutSessionService` only exposes `startSession(from
template:)`. (An earlier draft added a template-less `startEmptySession` —
removed since nothing in the UI called it and it wasn't part of the spec.)
