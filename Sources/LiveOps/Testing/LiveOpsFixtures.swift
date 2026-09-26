import Foundation
import LiveOpsCore

/// The golden fixtures shared by the kit and the apps: Remote Config templates
/// (`<name>.template.json`), each paired with the expected resolution
/// (`<name>.expected.json`), all against `catalog.manifest.json`.
public enum LiveOpsFixtures {
    public enum Failure: Error, CustomStringConvertible {
        case missing(String)
        public var description: String {
            switch self {
            case let .missing(name): "no fixture file named \(name) in LiveOpsTesting"
            }
        }
    }

    /// Every fixture name, sorted (the part before `.template.json`).
    public static var names: [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return files.filter { $0.hasSuffix(".template.json") }
            .map { String($0.dropLast(".template.json".count)) }
            .sorted()
    }

    /// The raw bytes of a fixture file.
    public static func data(_ file: String) throws -> Data {
        let url = directory.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.missing(file) }
        return try Data(contentsOf: url)
    }

    /// The template of a fixture, parsed as the transport would see it.
    public static func template(_ name: String) throws -> LiveOpsTemplate {
        try LiveOpsTemplate(data: data("\(name).template.json"))
    }

    /// The console values of a fixture.
    public static func values(_ name: String) throws -> LiveOpsValues {
        try template(name).values
    }

    /// What a fixture must resolve to against the catalogue.
    public struct Expected: Codable, Sendable, Equatable {
        /// Hand-written phase expectations, independent of the kit's code.
        public var probes: [LiveOpsFixtureProbe]
        /// The recorded resolution, reviewed by hand. Apps compare their current
        /// resolver against it before they migrate.
        public var report: LiveOpsReport?

        public init(probes: [LiveOpsFixtureProbe], report: LiveOpsReport?) {
            self.probes = probes
            self.report = report
        }
    }

    /// The catalogue every fixture resolves against.
    public static func catalog() throws -> LiveOpsManifest {
        try LiveOpsManifest(data: data("catalog.manifest.json"))
    }

    /// The expected resolution of a fixture.
    public static func expected(_ name: String) throws -> Expected {
        try JSONDecoder().decode(Expected.self, from: data("\(name).expected.json"))
    }

    /// The fixture's console values as a build with the catalogue's key list
    /// receives them (known, non-empty keys only).
    public static func deliveredValues(_ name: String) throws -> LiveOpsValues {
        try template(name).values(forKeys: catalog().keys)
    }

    /// The folder holding the fixtures inside this module's resource bundle.
    public static var directory: URL {
        Bundle.module.resourceURL?.appendingPathComponent("Fixtures") ?? Bundle.module.bundleURL
    }
}

/// One window phase at one moment in a fixture; `nil` means the window is removed.
public struct LiveOpsFixtureProbe: Codable, Sendable, Equatable {
    public var window: String
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
