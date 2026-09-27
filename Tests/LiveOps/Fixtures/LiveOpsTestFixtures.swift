import Foundation
import LiveOpsCore
import LiveOpsTesting

/// The kit's own conformance fixtures (test-only; not a product): Remote Config
/// templates (`<name>.template.json`), each with a golden expectation
/// (`<name>.expected.json`), all against `catalog.manifest.json`.
public enum TestFixtures {
    public enum Failure: Error, CustomStringConvertible {
        case missing(String)
        public var description: String {
            switch self {
            case let .missing(name): "no fixture file named \(name)"
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

    public static func data(_ file: String) throws -> Data {
        let url = directory.appendingPathComponent(file)
        guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.missing(file) }
        return try Data(contentsOf: url)
    }

    public static func template(_ name: String) throws -> LiveOpsTemplate {
        try LiveOpsTemplate(data: data("\(name).template.json"))
    }

    public static func values(_ name: String) throws -> LiveOpsValues {
        try template(name).values
    }

    public static func catalog() throws -> LiveOpsManifest {
        try LiveOpsManifest(data: data("catalog.manifest.json"))
    }

    public static func expected(_ name: String) throws -> LiveOpsGoldenExpectation {
        try LiveOpsGoldenExpectation(data: data("\(name).expected.json"))
    }

    /// The console values a build with the catalogue's key list receives.
    public static func deliveredValues(_ name: String) throws -> LiveOpsValues {
        try template(name).values(forKeys: catalog().keys)
    }

    /// The bundled folder at run time.
    public static var directory: URL {
        Bundle.module.resourceURL?.appendingPathComponent("Files") ?? Bundle.module.bundleURL
    }

    /// The folder in the source tree, for re-recording.
    public static let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Files")
}
