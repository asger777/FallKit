import Foundation

/// Resolution (rules #1, #2, #4, #7, #12): pure functions of the bundled value,
/// the console values and, where time matters, an injected moment.
public enum LiveOpsResolve {
    // MARK: Switches

    /// A switch only switches off (rule #2): `bundled AND NOT (value == false)`.
    /// `true`, unset and malformed all leave the bundle standing.
    public static func isEnabled(key: String, bundled: Bool = true, values: LiveOpsValues) -> Bool {
        bundled && LiveOpsParse.bool(values[key]) != false
    }

    public static func isEnabled(_ item: some LiveOpsSwitch, bundled: Bool = true, values: LiveOpsValues) -> Bool {
        isEnabled(key: item.parameterName, bundled: bundled, values: values)
    }

    // MARK: Numbers

    /// The console value when it is a whole number inside the bounds, otherwise
    /// the bundled value (rule #12: out of range is malformed, not clamped).
    public static func value(_ number: some LiveOpsNumber, values: LiveOpsValues) -> Int {
        LiveOpsParse.int(values[number.parameterName], in: number.bounds) ?? number.bundled
    }

    // MARK: Windows

    /// The console's override for one window, each field parsed on its own.
    public static func windowOverride<T>(
        kind: LiveOpsKind,
        id: String,
        values: LiveOpsValues,
        parse: (String?) -> T?
    ) -> LiveOpsWindowOverride<T> {
        LiveOpsWindowOverride(
            start: parse(values[LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.start)]),
            end: parse(values[LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.end)]),
            enabled: LiveOpsParse.bool(values[LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.enabled)])
        )
    }

    /// Overrides for the bundled ids only. An override for an id that is not
    /// bundled has nothing to attach to and is never read (rule #2). Empty
    /// overrides are omitted.
    public static func windowOverrides<T>(
        kind: LiveOpsKind,
        ids: [String],
        values: LiveOpsValues,
        parse: (String?) -> T?
    ) -> [String: LiveOpsWindowOverride<T>] {
        var result: [String: LiveOpsWindowOverride<T>] = [:]
        for id in ids {
            let override = windowOverride(kind: kind, id: id, values: values, parse: parse)
            if !override.isEmpty { result[id] = override }
        }
        return result
    }

    /// The bundled window with each overridden bound replaced on its own, or
    /// `nil` when the console switched it off. An inverted result is returned
    /// as is; it simply never reads as live.
    public static func effective<T>(
        bundled: LiveOpsWindow<T>,
        override: LiveOpsWindowOverride<T>?
    ) -> LiveOpsWindow<T>? {
        guard override?.isDisabled != true else { return nil }
        return moved(bundled, by: override)
    }

    /// Where `at` sits in `window`. Before the start is upcoming; at or past
    /// the end (by the end policy) is over. An inverted window is never live.
    public static func phase<T>(of window: LiveOpsWindow<T>, at: T, end: LiveOpsWindowEnd) -> LiveOpsPhase {
        if at < window.start { return .upcoming }
        switch end {
        case .exclusive where at >= window.end: return .over
        case .inclusive where at > window.end: return .over
        default: return window.start <= window.end ? .live : .over
        }
    }

    /// The phase of a bundled window under the console, or `nil` when a
    /// disabled window is `.removed`. A `.closed` disabled window is upcoming
    /// before its effective start and over from it on.
    public static func phase<T>(
        bundled: LiveOpsWindow<T>,
        override: LiveOpsWindowOverride<T>?,
        at: T,
        end: LiveOpsWindowEnd,
        whenDisabled: LiveOpsDisabled
    ) -> LiveOpsPhase? {
        if override?.isDisabled == true {
            switch whenDisabled {
            case .removed: return nil
            case .closed: return at < moved(bundled, by: override).start ? .upcoming : .over
            }
        }
        return phase(of: moved(bundled, by: override), at: at, end: end)
    }

    /// Shorthand for `phase(of:at:end:) == .live`.
    public static func isLive<T>(_ window: LiveOpsWindow<T>?, at: T, end: LiveOpsWindowEnd) -> Bool {
        guard let window else { return false }
        return phase(of: window, at: at, end: end) == .live
    }

    // MARK: Parameters

    /// The three parameters of an instant window, in console order: start, end, enabled.
    public static func parameters(kind: LiveOpsKind, id: String, bundled: LiveOpsWindow<Date>) -> [LiveOpsParameter] {
        [
            .instant(LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.start), bundled: bundled.start),
            .instant(LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.end), bundled: bundled.end),
            .bool(LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.enabled), bundled: true),
        ]
    }

    /// The three parameters of a day window, in console order: start, end, enabled.
    public static func parameters(kind: LiveOpsKind, id: String, bundled: LiveOpsWindow<LiveOpsDay>) -> [LiveOpsParameter] {
        [
            .day(LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.start), bundled: bundled.start),
            .day(LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.end), bundled: bundled.end),
            .bool(LiveOpsKey.name(kind, id: id, field: LiveOpsWindowField.enabled), bundled: true),
        ]
    }

    private static func moved<T>(_ bundled: LiveOpsWindow<T>, by override: LiveOpsWindowOverride<T>?) -> LiveOpsWindow<T> {
        LiveOpsWindow(start: override?.start ?? bundled.start, end: override?.end ?? bundled.end)
    }
}
