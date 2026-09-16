import Foundation
import SwiftData

/// Seeds a basic exercise library once, only when the library is completely
/// empty (a truly fresh install) — it does not diff against existing
/// exercises, so adding entries to `defaultExercises` later won't retroactively
/// reach installs that have already been seeded.
public enum ExerciseLibrarySeeder {
    public static let defaultExercises: [(name: String, muscleGroup: String)] = [
        ("Press banca", "Pecho"),
        ("Press inclinado con mancuernas", "Pecho"),
        ("Aperturas con mancuernas", "Pecho"),
        ("Fondos en paralelas", "Pecho"),
        ("Sentadilla", "Piernas"),
        ("Prensa de piernas", "Piernas"),
        ("Zancadas", "Piernas"),
        ("Peso muerto rumano", "Piernas"),
        ("Extensión de cuádriceps", "Piernas"),
        ("Curl femoral", "Piernas"),
        ("Elevación de talones", "Piernas"),
        ("Peso muerto", "Espalda"),
        ("Dominadas", "Espalda"),
        ("Remo con barra", "Espalda"),
        ("Remo con mancuerna", "Espalda"),
        ("Jalón al pecho", "Espalda"),
        ("Remo en polea baja", "Espalda"),
        ("Press militar", "Hombros"),
        ("Elevaciones laterales", "Hombros"),
        ("Elevaciones frontales", "Hombros"),
        ("Pájaros con mancuernas", "Hombros"),
        ("Curl de bíceps con barra", "Brazos"),
        ("Curl de bíceps con mancuernas", "Brazos"),
        ("Curl martillo", "Brazos"),
        ("Press francés", "Brazos"),
        ("Extensión de tríceps en polea", "Brazos"),
        ("Fondos de tríceps", "Brazos"),
        ("Plancha", "Core"),
        ("Elevación de piernas", "Core"),
        ("Crunch abdominal", "Core"),
        ("Rueda abdominal", "Core")
    ]

    /// Runs at app launch, before any UI can show an alert, so failures here
    /// can't be surfaced to the user the way `PersistenceResult` does for
    /// in-app mutations — but they must still not be swallowed silently.
    /// `assertionFailure` traps in debug builds (so it's caught during
    /// development) without crashing a release build over a library that,
    /// worst case, the user can still populate manually via "+" on the
    /// Ejercicios tab.
    @MainActor
    public static func seedIfNeeded(context: ModelContext) {
        let existingNames: Set<String>
        do {
            existingNames = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.name))
        } catch {
            assertionFailure("No se pudo leer la biblioteca de ejercicios antes de sembrarla: \(error)")
            return
        }
        guard existingNames.isEmpty else { return }

        for entry in defaultExercises {
            context.insert(Exercise(name: entry.name, muscleGroup: entry.muscleGroup))
        }
        do {
            try context.save()
        } catch {
            assertionFailure("No se pudo guardar la biblioteca de ejercicios sembrada: \(error)")
        }
    }
}
