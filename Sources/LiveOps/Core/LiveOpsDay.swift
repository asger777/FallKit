import Foundation

/// A calendar day, `YYYY-MM-DD`, for windows that mean "the same calendar day
/// wherever you are" (Huefall seasons, Wordfell collections). Never an instant.
public struct LiveOpsDay: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// A real Gregorian date, or `nil` (so 2026-02-30 and month 13 are rejected).
    public init?(year: Int, month: Int, day: Int) {
        let components = DateComponents(year: year, month: month, day: day)
        guard (1...9999).contains(year),
              let date = Self.utc.date(from: components),
              Self.utc.dateComponents([.year, .month, .day], from: date) == components
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Exactly `YYYY-MM-DD`: 4-2-2 ASCII digits naming a real date. No trimming
    /// here; ``LiveOpsParse/day(_:)`` trims console text first.
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard text.utf8.count == 10, parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day containing `date` in `calendar`'s time zone, counted on the
    /// Gregorian calendar whatever the calendar's own system is. The clock is
    /// never read: the caller passes `now`.
    public init(date: Date, calendar: Calendar) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        // Components of a real date are always a real date.
        self.year = parts.year ?? 1
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    /// The console spelling, zero-padded.
    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { iso }

    public static func < (lhs: LiveOpsDay, rhs: LiveOpsDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let day = LiveOpsDay(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a YYYY-MM-DD day: \(text)")
        }
        self = day
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()
}
