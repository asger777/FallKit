/// How a build resolves the console: one row per parameter and per window.
/// The CLI prints it; the golden fixtures pin it.
public struct LiveOpsReport: Sendable, Equatable, Codable {
    public struct Parameter: Sendable, Equatable, Codable {
        public var name: String
        public var type: String
        public var bundled: String
        /// The raw console value, `nil` when unset.
        public var console: String?
        /// `unset`, `applied`, `malformed` or `outOfRange`.
        public var reading: String
        /// What the build uses: the switch rule for bools, the applied value or
        /// the bundle otherwise.
        public var effective: String

        public init(name: String, type: String, bundled: String, console: String?, reading: String, effective: String) {
            self.name = name
            self.type = type
            self.bundled = bundled
            self.console = console
            self.reading = reading
            self.effective = effective
        }
    }

    public struct Window: Sendable, Equatable, Codable {
        /// `kind/id`.
        public var window: String
        /// `nil` when `enabled=false`.
        public var start: String?
        public var end: String?
        public var disabled: Bool
        public var whenDisabled: LiveOpsDisabled

        public init(window: String, start: String?, end: String?, disabled: Bool, whenDisabled: LiveOpsDisabled) {
            self.window = window
            self.start = start
            self.end = end
            self.disabled = disabled
            self.whenDisabled = whenDisabled
        }
    }

    public var parameters: [Parameter]
    public var windows: [Window]

    public init(parameters: [Parameter], windows: [Window]) {
        self.parameters = parameters
        self.windows = windows
    }
}

public extension LiveOpsManifest {
    /// Resolves every parameter and window against console `values` (already
    /// filtered to known, non-empty keys, as the transport delivers them).
    func report(values: LiveOpsValues) -> LiveOpsReport {
        let rows = parameters.map { parameter -> LiveOpsReport.Parameter in
            let reading = parameter.read(in: values)
            return LiveOpsReport.Parameter(
                name: parameter.name,
                type: parameter.type.code,
                bundled: parameter.bundled,
                console: values[parameter.name],
                reading: reading.code,
                effective: effective(parameter, reading: reading, values: values)
            )
        }
        let windowRows = windows.map { window -> LiveOpsReport.Window in
            let effective = window.effective(values: values)
            return LiveOpsReport.Window(
                window: window.key,
                start: effective?.start,
                end: effective?.end,
                disabled: effective == nil,
                whenDisabled: window.whenDisabled
            )
        }
        return LiveOpsReport(parameters: rows, windows: windowRows)
    }

    /// The window named `kind/id`.
    func window(_ key: String) -> Window? {
        windows.first { $0.key == key }
    }

    private func effective(_ parameter: LiveOpsParameter, reading: LiveOpsParameter.Reading, values: LiveOpsValues) -> String {
        switch parameter.type {
        case .bool:
            let bundled = LiveOpsParse.bool(parameter.bundled) ?? true
            return String(LiveOpsResolve.isEnabled(key: parameter.name, bundled: bundled, values: values))
        case .int, .instant, .day:
            return reading.appliedValue ?? parameter.bundled
        }
    }
}

public extension LiveOpsParameter.ValueType {
    /// The manifest spelling.
    var code: String {
        switch self {
        case .instant: "instant"
        case .day: "day"
        case .bool: "bool"
        case .int: "int"
        }
    }
}

public extension LiveOpsParameter.Reading {
    /// The report spelling.
    var code: String {
        switch self {
        case .unset: "unset"
        case .applied: "applied"
        case .malformed: "malformed"
        case .outOfRange: "outOfRange"
        }
    }
}
