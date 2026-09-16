import Foundation

/// Pure `Double` <-> `String` conversion for decimal kg weights, kept
/// UI-agnostic so precision and transient-input edge cases are covered by
/// fast domain tests instead of fragile UI tests.
public enum WeightFormatting {
    /// Formats a weight for display: whole numbers show no decimals, others
    /// show up to 2 fraction digits with no trailing zeros. Real plates go
    /// down to quarter-kilo increments (e.g. 7.25), so this never rounds a
    /// value the user actually entered down to one decimal place.
    public static func string(for value: Double?) -> String {
        guard let value else { return "" }
        return string(for: value)
    }

    public static func string(for value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        // Fixed locale rather than `.current`: weight display must be
        // deterministic (for tests, and so the number a user sees always
        // matches what's stored) regardless of device region. Parsing still
        // accepts "," as well as "." on input, since the decimal keypad
        // itself follows the device locale.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Result of parsing user-entered weight text.
    public enum ParseResult: Equatable {
        /// The text was empty — meaning "no weight entered."
        case empty
        /// A valid non-negative weight.
        case value(Double)
        /// Neither empty nor a valid non-negative number (a bare "-", a
        /// stray character, a negative value, mid-edit noise). Callers
        /// should leave the previously persisted value untouched rather
        /// than clobbering it with `nil` while the user is still typing.
        case invalid
    }

    /// Parses user-entered text into a non-negative weight. Accepts both "."
    /// and "," as the decimal separator, since the on-screen decimal keypad
    /// shows "," in some locales.
    public static func parse(_ text: String) -> ParseResult {
        if text.isEmpty { return .empty }
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let parsed = Double(normalized), parsed >= 0 else { return .invalid }
        return .value(parsed)
    }
}
