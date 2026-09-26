import Foundation

/// Everything one build reads from the console: `liveops-manifest.json`,
/// schema 1 (Docs/manifest.md). Each app emits it from a unit test; the CLI
/// and the golden fixtures resolve it with the same Core functions the app uses.
public struct LiveOpsManifest: Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public struct Window: Sendable, Equatable, Codable {
        public var kind: LiveOpsKind
        public var id: String
        public var type: LiveOpsWindowType
        /// Bundled bounds, spelled as the console would spell them.
        public var start: String
        public var end: String
        public var endPolicy: LiveOpsWindowEnd
        public var whenDisabled: LiveOpsDisabled
        /// The App Store Connect In-App Event reference name that must match this window, if any.
        public var inAppEvent: String?

        public init(kind: LiveOpsKind, id: String, type: LiveOpsWindowType, start: String, end: String,
                    endPolicy: LiveOpsWindowEnd, whenDisabled: LiveOpsDisabled, inAppEvent: String? = nil) {
            self.kind = kind
            self.id = id
            self.type = type
            self.start = start
            self.end = end
            self.endPolicy = endPolicy
            self.whenDisabled = whenDisabled
            self.inAppEvent = inAppEvent
        }

        /// `kind/id`, as reports and fixtures name a window.
        public var key: String { "\(kind.rawValue)/\(id)" }

        public var startKey: String { LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.start) }
        public var endKey: String { LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.end) }
        public var enabledKey: String { LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.enabled) }
    }

    public var schemaVersion: Int
    /// Display name only (never an identifier; the repo is public).
    public var app: String?
    public var parameters: [LiveOpsParameter]
    public var windows: [Window]

    public init(app: String? = nil, parameters: [LiveOpsParameter], windows: [Window] = []) {
        self.schemaVersion = Self.currentSchemaVersion
        self.app = app
        self.parameters = parameters
        self.windows = windows
    }

    /// The transport's key list.
    public var keys: [String] { parameters.keys }

    /// Every problem with the manifest; empty when it is sound.
    public var problems: [String] {
        var found = parameters.problems
        let names = Set(parameters.map(\.name))
        for window in windows {
            for key in [window.startKey, window.endKey, window.enabledKey] where !names.contains(key) {
                found.append("\(window.key): parameter \(key) is not listed")
            }
            if window.bounds(start: window.start, end: window.end) == nil {
                found.append("\(window.key): bundled start or end is not a valid \(window.type.rawValue)")
            }
        }
        return found
    }
}

// MARK: - Coding

extension LiveOpsManifest: Codable {
    public enum Failure: Error, CustomStringConvertible, Equatable {
        case unsupportedSchema(Int)
        case invalidKey(String)

        public var description: String {
            switch self {
            case let .unsupportedSchema(version): "liveops manifest schema \(version) is not supported (expected 1)"
            case let .invalidKey(key): "liveops manifest lists an invalid console key: \(key)"
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, app, parameters, windows
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else { throw Failure.unsupportedSchema(version) }
        schemaVersion = version
        app = try container.decodeIfPresent(String.self, forKey: .app)
        parameters = try container.decode([LiveOpsParameter].self, forKey: .parameters)
        windows = try container.decodeIfPresent([Window].self, forKey: .windows) ?? []
        if let bad = parameters.first(where: { !LiveOpsKey.isValid($0.name) }) {
            throw Failure.invalidKey(bad.name)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encodeIfPresent(app, forKey: .app)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(windows, forKey: .windows)
    }

    /// Decodes a manifest file.
    public init(data: Data) throws {
        self = try JSONDecoder().decode(LiveOpsManifest.self, from: data)
    }

    /// A stable, human-diffable encoding (sorted keys, pretty-printed).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

extension LiveOpsParameter: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, type, bundled, min, max
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let bundled = try container.decode(String.self, forKey: .bundled)
        let type: ValueType
        switch try container.decode(String.self, forKey: .type) {
        case "instant": type = .instant
        case "day": type = .day
        case "bool": type = .bool
        case "int":
            let low = try container.decode(Int.self, forKey: .min)
            let high = try container.decode(Int.self, forKey: .max)
            guard low <= high else {
                throw DecodingError.dataCorruptedError(forKey: .max, in: container, debugDescription: "\(name): max < min")
            }
            type = .int(low...high)
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "\(name): unknown type \(other)")
        }
        self.init(name: name, type: type, bundled: bundled)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(bundled, forKey: .bundled)
        switch type {
        case .instant: try container.encode("instant", forKey: .type)
        case .day: try container.encode("day", forKey: .type)
        case .bool: try container.encode("bool", forKey: .type)
        case let .int(bounds):
            try container.encode("int", forKey: .type)
            try container.encode(bounds.lowerBound, forKey: .min)
            try container.encode(bounds.upperBound, forKey: .max)
        }
    }
}

// MARK: - Window resolution by type

extension LiveOpsManifest.Window {
    /// Parses a pair of bounds with this window's value type.
    func bounds(start: String, end: String) -> (start: String, end: String)? {
        switch type {
        case .instant:
            guard let low = LiveOpsParse.instant(start), let high = LiveOpsParse.instant(end) else { return nil }
            return (LiveOpsParse.string(instant: low), LiveOpsParse.string(instant: high))
        case .day:
            guard let low = LiveOpsParse.day(start), let high = LiveOpsParse.day(end) else { return nil }
            return (low.iso, high.iso)
        }
    }

    /// The effective window as console spellings, `nil` when removed or closed
    /// by `enabled=false`.
    public func effective(values: LiveOpsValues) -> (start: String, end: String)? {
        switch type {
        case .instant:
            guard let bundled = instantWindow else { return nil }
            let override = LiveOpsResolve.windowOverride(kind: kind, id: id, values: values, parse: LiveOpsParse.instant)
            guard let window = LiveOpsResolve.effective(bundled: bundled, override: override) else { return nil }
            return (LiveOpsParse.string(instant: window.start), LiveOpsParse.string(instant: window.end))
        case .day:
            guard let bundled = dayWindow else { return nil }
            let override = LiveOpsResolve.windowOverride(kind: kind, id: id, values: values, parse: LiveOpsParse.day)
            guard let window = LiveOpsResolve.effective(bundled: bundled, override: override) else { return nil }
            return (window.start.iso, window.end.iso)
        }
    }

    /// The phase at `at` (an instant or a day, matching ``type``) under the
    /// console. `nil` when removed, or when `at` does not parse.
    public func phase(at: String, values: LiveOpsValues) -> LiveOpsPhase? {
        switch type {
        case .instant:
            guard let bundled = instantWindow, let moment = LiveOpsParse.instant(at) else { return nil }
            let override = LiveOpsResolve.windowOverride(kind: kind, id: id, values: values, parse: LiveOpsParse.instant)
            return LiveOpsResolve.phase(bundled: bundled, override: override, at: moment, end: endPolicy,
                                        whenDisabled: whenDisabled)
        case .day:
            guard let bundled = dayWindow, let day = LiveOpsParse.day(at) else { return nil }
            let override = LiveOpsResolve.windowOverride(kind: kind, id: id, values: values, parse: LiveOpsParse.day)
            return LiveOpsResolve.phase(bundled: bundled, override: override, at: day, end: endPolicy,
                                        whenDisabled: whenDisabled)
        }
    }

    var instantWindow: LiveOpsWindow<Date>? {
        guard let low = LiveOpsParse.instant(start), let high = LiveOpsParse.instant(end) else { return nil }
        return LiveOpsWindow(start: low, end: high)
    }

    var dayWindow: LiveOpsWindow<LiveOpsDay>? {
        guard let low = LiveOpsParse.day(start), let high = LiveOpsParse.day(end) else { return nil }
        return LiveOpsWindow(start: low, end: high)
    }
}
