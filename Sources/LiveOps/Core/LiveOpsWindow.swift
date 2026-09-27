import Foundation

/// A bundled window: an event, season or collection runs from `start` to `end`.
/// `T` is `Date` for instant windows or ``LiveOpsDay`` for day windows.
public struct LiveOpsWindow<T: Comparable & Sendable>: Sendable {
    public var start: T
    public var end: T

    public init(start: T, end: T) {
        self.start = start
        self.end = end
    }
}

extension LiveOpsWindow: Equatable where T: Equatable {}
extension LiveOpsWindow: Hashable where T: Hashable {}

/// What the console says about one window. Each field is read on its own, so
/// a malformed start never takes a valid end down with it (rule #4).
public struct LiveOpsWindowOverride<T: Comparable & Sendable>: Sendable {
    public var start: T?
    public var end: T?
    /// Only `false` has an effect: an override never creates or re-enables (rule #2).
    public var enabled: Bool?

    public init(start: T? = nil, end: T? = nil, enabled: Bool? = nil) {
        self.start = start
        self.end = end
        self.enabled = enabled
    }

    /// True when the console set nothing readable for this window.
    public var isEmpty: Bool { start == nil && end == nil && enabled == nil }

    /// True when the console switched this window off.
    public var isDisabled: Bool { enabled == false }
}

extension LiveOpsWindowOverride: Equatable where T: Equatable {}
extension LiveOpsWindowOverride: Hashable where T: Hashable {}

/// The value type of a window's bounds.
public enum LiveOpsWindowType: String, Sendable, Codable {
    /// ISO-8601 instants (`Date`).
    case instant
    /// `YYYY-MM-DD` calendar days (``LiveOpsDay``).
    case day
}

/// Whether the end of a window is still inside it.
public enum LiveOpsWindowEnd: String, Sendable, Codable {
    /// `start <= t < end`: the end is the first moment after the window. The usual choice for instant windows.
    case exclusive
    /// `start <= t <= end`: the end is the last moment inside it. The usual choice for day windows, where the end day is the last day.
    case inclusive
}

/// Where a moment sits relative to a window.
public enum LiveOpsPhase: String, Sendable, Codable {
    case upcoming
    case live
    case over
}

/// What `enabled=false` does to a window.
public enum LiveOpsDisabled: String, Sendable, Codable {
    /// The window is gone: no phase at all. The recommended default.
    case removed
    /// The window is closed: upcoming before its start, over from its start on. Use it when a
    /// disabled window must still be shown, for example as "ended".
    case closed
}

/// The three fields every window has in the console.
public enum LiveOpsWindowField {
    public static let start = "start"
    public static let end = "end"
    public static let enabled = "enabled"
    /// In the order the apps list them.
    public static let all = [start, end, enabled]
}
