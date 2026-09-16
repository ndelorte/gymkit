import Testing
@testable import AppGymKit

struct WeightFormattingTests {

    @Test func formatsQuarterKiloIncrementWithoutLosingPrecision() {
        #expect(WeightFormatting.string(for: 7.25) == "7.25")
    }

    @Test func formatsOneDecimalWithoutTrailingZero() {
        #expect(WeightFormatting.string(for: 82.5) == "82.5")
    }

    @Test func formatsIntegerWeightWithNoDecimals() {
        #expect(WeightFormatting.string(for: 100) == "100")
        #expect(WeightFormatting.string(for: 12.0) == "12")
    }

    @Test func formatsNilAsEmptyString() {
        #expect(WeightFormatting.string(for: nil) == "")
    }

    @Test func parsesQuarterKiloIncrement() {
        #expect(WeightFormatting.parse("7.25") == .value(7.25))
    }

    @Test func parsesCommaAsDecimalSeparator() {
        #expect(WeightFormatting.parse("82,5") == .value(82.5))
    }

    @Test func parsesEmptyTextAsEmpty() {
        #expect(WeightFormatting.parse("") == .empty)
    }

    @Test func rejectsNegativeValueAsInvalid() {
        #expect(WeightFormatting.parse("-5") == .invalid)
    }

    @Test func rejectsNonNumericTextAsInvalid() {
        #expect(WeightFormatting.parse("abc") == .invalid)
    }

    /// A transient state while typing a decimal (the "." with nothing after
    /// it yet) must still parse — Double's own initializer accepts a
    /// trailing dot — so the value isn't lost mid-edit.
    @Test func parsesTrailingDecimalPointTransientState() {
        #expect(WeightFormatting.parse("82.") == .value(82))
    }

    /// A bare "-" (e.g. typed and not yet followed by digits, or a stray
    /// keystroke) must be reported as invalid rather than silently becoming
    /// zero or crashing — callers use this to leave the last valid value
    /// alone instead of clobbering it.
    @Test func bareMinusSignIsInvalidNotZero() {
        #expect(WeightFormatting.parse("-") == .invalid)
    }
}
