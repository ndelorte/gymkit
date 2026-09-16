import SwiftUI
import SwiftData

/// Small, reusable pattern so a persistence failure surfaces to the user
/// instead of the UI silently carrying on as if the save succeeded. Every
/// screen that mutates the store should route its `context.save()` through
/// `PersistenceResult.save` and feed the result into `.persistenceErrorAlert`.
enum PersistenceResult {
    /// Saves `context`. On failure, rolls back the pending changes — so
    /// `@Query` results reflect what's actually on disk rather than an
    /// optimistic change that never persisted — and returns a message to
    /// show the user. Returns `nil` on success.
    @discardableResult
    static func save(_ context: ModelContext) -> String? {
        do {
            try context.save()
            return nil
        } catch {
            context.rollback()
            return "No se pudo guardar el cambio: \(error.localizedDescription)"
        }
    }
}

extension View {
    /// Attach once per screen, bound to a `@State private var saveError: String?`
    /// that `PersistenceResult.save`'s return value feeds into.
    func persistenceErrorAlert(_ message: Binding<String?>, title: String = "No se pudo guardar") -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { isPresented in if !isPresented { message.wrappedValue = nil } }
        )) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
