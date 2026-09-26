import Foundation

/// One parameter a build reads, described for tests, the tooling and the manifest.
public struct LiveOpsParameter: Hashable, Sendable {
    public enum ValueType: Hashable, Sendable {
        /// An ISO-8601 instant with an offset (StreakFlame, Lineburst, Boltfall windows).
        case instant
        /// A `YYYY-MM-DD` calendar day (Huefall, Wordfell windows).
        case day
        case bool
        /// A whole number inside inclusive bounds (rule #12).
        case int(ClosedRange<Int>)
    }

    /// What the resolver makes of one console value.
    public enum Reading: Hashable, Sendable {
        /// No console value: the bundle stands.
        case unset
        /// A valid value, spelled the way the tooling prints it (bools as
        /// `true`/`false`, instants in UTC with `Z`, trimmed numbers).
        case applied(String)
        /// Not parseable for this type: ignored for this key only.
        case malformed
        /// A whole number outside the bounds. Resolves exactly like `.malformed`;
        /// the tooling reports it separately.
        case outOfRange(ClosedRange<Int>)

        /// True when the console value is ignored: `.malformed` or `.outOfRange`.
        public var isMalformed: Bool {
            switch self {
            case .malformed, .outOfRange: true
            case .unset, .applied: false
            }
        }

        /// The applied value, or `nil` when the bundle stands.
        public var appliedValue: String? {
            if case let .applied(value) = self { value } else { nil }
        }
    }

    public let name: String
    public let type: ValueType
    /// The bundled value, spelled as the console would spell it.
    public let bundled: String

    public init(name: String, type: ValueType, bundled: String) {
        self.name = name
        self.type = type
        self.bundled = bundled
    }

    public static func bool(_ name: String, bundled: Bool) -> LiveOpsParameter {
        LiveOpsParameter(name: name, type: .bool, bundled: String(bundled))
    }

    public static func int(_ name: String, bounds: ClosedRange<Int>, bundled: Int) -> LiveOpsParameter {
        LiveOpsParameter(name: name, type: .int(bounds), bundled: String(bundled))
    }

    public static func instant(_ name: String, bundled: Date) -> LiveOpsParameter {
        LiveOpsParameter(name: name, type: .instant, bundled: LiveOpsParse.string(instant: bundled))
    }

    public static func day(_ name: String, bundled: LiveOpsDay) -> LiveOpsParameter {
        LiveOpsParameter(name: name, type: .day, bundled: bundled.iso)
    }

    /// Classifies one raw console value (`nil` when the key is unset).
    public func read(_ raw: String?) -> Reading {
        guard let raw else { return .unset }
        switch type {
        case .instant:
            guard let instant = LiveOpsParse.instant(raw) else { return .malformed }
            return .applied(LiveOpsParse.string(instant: instant))
        case .day:
            guard let day = LiveOpsParse.day(raw) else { return .malformed }
            return .applied(day.iso)
        case .bool:
            guard let flag = LiveOpsParse.bool(raw) else { return .malformed }
            return .applied(String(flag))
        case let .int(bounds):
            if let value = LiveOpsParse.int(raw, in: bounds) { return .applied(String(value)) }
            // "A number, but outside the bounds" vs "not a number": the tooling
            // says which; the app treats both as malformed.
            guard let value = LiveOpsParse.wholeNumber(raw), !bounds.contains(value) else { return .malformed }
            return .outOfRange(bounds)
        }
    }

    /// The reading for this parameter in `values`.
    public func read(in values: LiveOpsValues) -> Reading {
        read(values[name])
    }
}

public extension Array where Element == LiveOpsParameter {
    /// The keys a transport reads, in the given order, without duplicates.
    var keys: [String] {
        var seen = Set<String>()
        return compactMap { seen.insert($0.name).inserted ? $0.name : nil }
    }

    /// Every problem with this parameter list; empty when it is sound. Checks
    /// console key validity and length, duplicates, and that each bundled value
    /// reads as applied (so a bundled number sits inside its own bounds).
    var problems: [String] {
        var found: [String] = []
        var seen = Set<String>()
        for parameter in self {
            if !LiveOpsKey.isValid(parameter.name) {
                found.append("\(parameter.name): not a valid console key")
            }
            if parameter.name.count > LiveOpsParameter.maximumKeyLength {
                found.append("\(parameter.name): longer than \(LiveOpsParameter.maximumKeyLength) characters")
            }
            if !seen.insert(parameter.name).inserted {
                found.append("\(parameter.name): listed twice")
            }
            if parameter.read(parameter.bundled).appliedValue == nil {
                found.append("\(parameter.name): bundled value \"\(parameter.bundled)\" does not read as applied")
            }
        }
        return found
    }
}

public extension LiveOpsParameter {
    /// Remote Config's limit on a parameter key.
    static let maximumKeyLength = 256
}
