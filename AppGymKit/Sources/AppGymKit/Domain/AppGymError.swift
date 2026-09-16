import Foundation

public enum AppGymError: Error, Equatable, LocalizedError {
    case activeSessionAlreadyExists
    case sessionNotActive
    case invalidBackup(reason: String)

    public var errorDescription: String? {
        switch self {
        case .activeSessionAlreadyExists:
            return "Ya hay un entrenamiento activo."
        case .sessionNotActive:
            return "El entrenamiento no está activo."
        case .invalidBackup(let reason):
            return "Copia de seguridad inválida: \(reason)"
        }
    }
}
