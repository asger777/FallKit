/// A bounded number the console can move, such as an ad frequency or a free
/// allowance (rule #12). A value outside `bounds` is malformed, never clamped.
public protocol LiveOpsNumber: Sendable {
    var parameterName: String { get }
    /// The bundled value. It must sit inside `bounds` (``LiveOpsParameter/problems`` checks this).
    var bundled: Int { get }
    var bounds: ClosedRange<Int> { get }
}

public extension LiveOpsNumber {
    /// The number described for the tooling.
    var parameter: LiveOpsParameter {
        .int(parameterName, bounds: bounds, bundled: bundled)
    }
}
