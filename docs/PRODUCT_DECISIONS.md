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

## v0.1.1 hardening pass

**Backup active-session semantics — reversed from the original MVP call.**
The MVP originally forced every imported session to `isActive = false`,
reasoning that a backup restore had no business resurrecting a live
workout. The v0.1.1 hardening goal explicitly asked for a true functional
roundtrip instead: if you back up mid-workout, restoring that backup should
put you right back in that workout, pending sets and all. Implemented that,
with `validate` rejecting any backup describing more than one active session
so the single-active-session invariant still can't be bypassed. The
original concern (a backup accidentally reactivating a stale session) is
handled differently now: import always replaces the *entire* store, so
there's never a leftover pre-existing active session for the restored one to
collide with — the risk that motivated forcing `isActive = false` doesn't
actually exist once you look at import as "replace everything," not
"merge."

**Weight display uses a fixed locale, not the device's.** Formatting
0.25kg-increment weights (`WeightFormatting.string(for:)`) needs to be
deterministic for fast domain tests, and `NumberFormatter` with
`Locale.current` isn't (it silently produces "7,25" instead of "7.25" on a
comma-decimal device, breaking equality assertions). Pinned the formatter to
`en_US_POSIX`. Parsing still accepts both "," and "." as input, since the
on-screen decimal keypad itself follows the device locale — only the
*displayed* string is fixed. Net effect: every AppGym user sees weights
formatted the same way regardless of region, which is arguably more
predictable for a personal numeric log than following region settings.

**Duplicate exercise names: reactivate archived matches automatically,
rather than asking.** The hardening goal explicitly left this open
("evaluar reactivarlo o avisar"). Chose auto-reactivate over a confirmation
prompt: an archived exercise with the same (trimmed, case-insensitive) name
is, by construction, the same exercise the user is trying to recreate —
there's no real decision for them to make, and a confirmation dialog here
would just be an extra tap for a foregone conclusion. An *active* duplicate
is different (no reactivation to do), so that case keeps the create form
open with a message instead of silently doing nothing or creating a
same-named twin.

**Historical set "completed" status is derived from recorded data, not a
toggle.** The history editor has no explicit complete/incomplete switch
(unlike the active workout screen) — editing history means recording what
actually happened, so a `SetEntry` there is "completed" exactly when
`hasRecordedPerformance` is true (weight or reps present), recomputed on
every edit to either field. This was the simplest fix for "adding a set in
history must not silently persist as an empty performed set" without
inventing new UI for something that never needed a toggle in the first
place.
