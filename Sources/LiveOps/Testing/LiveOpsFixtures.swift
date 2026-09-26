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

    /// The folder holding the fixtures inside this module's resource bundle.
    public static var directory: URL {
        Bundle.module.resourceURL?.appendingPathComponent("Fixtures") ?? Bundle.module.bundleURL
    }
}
