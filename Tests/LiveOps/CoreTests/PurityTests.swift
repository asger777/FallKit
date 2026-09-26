import Foundation
import Testing

/// LiveOpsCore imports Foundation only and never reads the clock, the process
/// environment, defaults or the file system (CLAUDE.md architecture rule 2).
@Suite("Core purity")
struct PurityTests {
    static let coreDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // CoreTests
        .deletingLastPathComponent()      // LiveOps
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // repo
        .appendingPathComponent("Sources/LiveOps/Core")

    static func sources() throws -> [(String, String)] {
        let names = try FileManager.default.contentsOfDirectory(atPath: coreDirectory.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        return try names.map { name in
            (name, try String(contentsOf: coreDirectory.appendingPathComponent(name), encoding: .utf8))
        }
    }

    @Test("Core sources exist")
    func sourcesExist() throws {
        #expect(try Self.sources().count >= 8)
    }

    @Test("Core imports Foundation only")
    func importsFoundationOnly() throws {
        for (name, text) in try Self.sources() {
            let imports = text.split(separator: "\n").filter { $0.hasPrefix("import ") }
            for line in imports {
                #expect(line == "import Foundation", "\(name): \(line)")
            }
        }
    }

    @Test("Core never reads the clock, the environment, defaults or files", arguments: [
        "Date()", "Date.now", ".now()", "ProcessInfo", "UserDefaults", "FileManager", "Bundle.main", "NSClassFromString",
    ])
    func noAmbientState(token: String) throws {
        for (name, text) in try Self.sources() {
            #expect(!text.contains(token), "\(name) contains \(token)")
        }
    }
}
