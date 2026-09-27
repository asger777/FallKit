import Foundation
import LiveOpsCore

/// Golden checks for an app's own live-ops configuration: given its manifest,
/// the console values of a saved template and the expected outcome, list every
/// difference. Keep the probes hand-written (they state what *should* happen)
/// and let the report be recorded and reviewed (it pins what *does* happen).
public enum LiveOpsGolden {
    /// Every mismatch, one readable line each; empty when everything matches.
    /// `values` are the console values as the build receives them, usually
    /// `LiveOpsTemplate.values(forKeys: manifest.keys)`.
    public static func mismatches(manifest: LiveOpsManifest, values: LiveOpsValues,
                                  expected: LiveOpsGoldenExpectation) -> [String] {
        var found: [String] = []
        for probe in expected.probes {
            guard let window = manifest.window(probe.window) else {
                found.append("probe: no window \(probe.window) in the manifest")
                continue
            }
            let actual = window.phase(at: probe.at, values: values)
            if actual != probe.phase {
                found.append("\(probe.window) at \(probe.at): expected \(describe(probe.phase)), got \(describe(actual))")
            }
        }
        if let report = expected.report {
            found += differences(expected: report, actual: manifest.report(values: values))
        }
        return found
    }

    /// The expectation with its report recorded from the current resolution;
    /// the probes are kept as given.
    public static func recording(manifest: LiveOpsManifest, values: LiveOpsValues,
                                 probes: [LiveOpsGoldenProbe]) -> LiveOpsGoldenExpectation {
        LiveOpsGoldenExpectation(probes: probes, report: manifest.report(values: values))
    }

    private static func describe(_ phase: LiveOpsPhase?) -> String {
        phase?.rawValue ?? "removed"
    }

    private static func differences(expected: LiveOpsReport, actual: LiveOpsReport) -> [String] {
        var found: [String] = []
        let actualRows = Dictionary(actual.parameters.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        for row in expected.parameters {
            guard let other = actualRows[row.name] else {
                found.append("report: parameter \(row.name) is no longer in the manifest")
                continue
            }
            if other != row {
                found.append("report: \(row.name): expected \(row.reading)/\(row.effective), got \(other.reading)/\(other.effective)")
            }
        }
        for row in actual.parameters where !expected.parameters.contains(where: { $0.name == row.name }) {
            found.append("report: parameter \(row.name) is new; re-record the expectation")
        }
        let actualWindows = Dictionary(actual.windows.map { ($0.window, $0) }, uniquingKeysWith: { first, _ in first })
        for row in expected.windows where actualWindows[row.window] != row {
            found.append("report: window \(row.window) differs")
        }
        for row in actual.windows where !expected.windows.contains(where: { $0.window == row.window }) {
            found.append("report: window \(row.window) is new; re-record the expectation")
        }
        return found
    }
}

/// What one golden file expects.
public struct LiveOpsGoldenExpectation: Codable, Sendable, Equatable {
    /// Hand-written phase expectations.
    public var probes: [LiveOpsGoldenProbe]
    /// The recorded resolution, reviewed by hand; `nil` checks probes only.
    public var report: LiveOpsReport?

    public init(probes: [LiveOpsGoldenProbe], report: LiveOpsReport? = nil) {
        self.probes = probes
        self.report = report
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(LiveOpsGoldenExpectation.self, from: data)
    }

    /// A stable, human-diffable encoding with a trailing newline.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }
}

/// One window phase at one moment; a `nil` phase means the window is removed.
public struct LiveOpsGoldenProbe: Codable, Sendable, Equatable {
    /// `kind/id`, as the manifest names windows.
    public var window: String
    /// An instant or a day, matching the window's type.
    public var at: String
    public var phase: LiveOpsPhase?

    public init(window: String, at: String, phase: LiveOpsPhase?) {
        self.window = window
        self.at = at
        self.phase = phase
    }

    private enum CodingKeys: String, CodingKey { case window, at, phase }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(window, forKey: .window)
        try container.encode(at, forKey: .at)
        try container.encode(phase, forKey: .phase)   // explicit null for "removed"
    }
}
