import Foundation

/// Strict parsers (rule #4): `nil` means malformed, and a malformed value is
/// dropped for its own key only. Every parser trims whitespace and newlines,
/// and an empty result is `nil`.
public enum LiveOpsParse {
    /// `true`, `1`, `yes` → true; `false`, `0`, `no` → false; case-insensitive.
    /// Anything else (`on`, `off`, `2`, `enabled`) is malformed.
    public static func bool(_ text: String?) -> Bool? {
        switch trimmed(text)?.lowercased() {
        case "true", "1", "yes": true
        case "false", "0", "no": false
        default: nil
        }
    }

    /// A base-10 integer inside `bounds` (rule #12). Out of range is malformed,
    /// not clamped to the nearest bound: a typo'd `50` must not quietly become
    /// the maximum.
    public static func int(_ text: String?, in bounds: ClosedRange<Int>) -> Int? {
        guard let text = trimmed(text), let value = Int(text), bounds.contains(value) else { return nil }
        return value
    }

    /// A whole number, ignoring bounds: how the tooling tells "out of range"
    /// from "not a number".
    public static func wholeNumber(_ text: String?) -> Int? {
        guard let text = trimmed(text) else { return nil }
        return Int(text)
    }

    /// An ISO-8601 internet date-time with a time-zone designator
    /// (`2026-10-01T00:00:00Z`, `2026-10-01T04:00:00+04:00`). Date-only strings,
    /// fractional seconds and epoch digits are malformed. A formatter per call:
    /// this runs a handful of times per activation, and the type is not `Sendable`.
    public static func instant(_ text: String?) -> Date? {
        guard let text = trimmed(text) else { return nil }
        return ISO8601DateFormatter().date(from: text)
    }

    /// The console spelling of an instant, in UTC with `Z`, for the tooling and
    /// bundled defaults.
    public static func string(instant: Date) -> String {
        ISO8601DateFormatter().string(from: instant)
    }

    /// A strict calendar day, `YYYY-MM-DD`. An instant is malformed here: a day
    /// window must not quietly become a moment in one time zone.
    public static func day(_ text: String?) -> LiveOpsDay? {
        guard let text = trimmed(text) else { return nil }
        return LiveOpsDay(text)
    }

    static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
