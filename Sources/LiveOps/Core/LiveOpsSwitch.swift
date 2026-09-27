/// Something the console can switch **off** (rule #2), such as a feature, a
/// placement, a promo or an offer. Conforming enums keep their own bundled
/// values: `bundled` is passed at the call site, because it may depend on
/// context the switch does not know, such as a saved configuration.
public protocol LiveOpsSwitch: Sendable {
    /// The console key, usually `LiveOpsKey.name(kind, id: rawValue, field: "enabled")`.
    var parameterName: String { get }
}

public extension LiveOpsSwitch {
    /// The switch described for the tooling.
    func parameter(bundled: Bool = true) -> LiveOpsParameter {
        .bool(parameterName, bundled: bundled)
    }
}
