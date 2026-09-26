import Foundation
import LiveOpsCore
import LiveOpsTesting
import Testing

/// The golden fixtures (PLAN §8). Probes are written by hand from
/// Docs/semantics.md; reports are recorded, then reviewed. To re-record after a
/// deliberate behaviour change, run `FALLKIT_RECORD_FIXTURES=1 swift test
/// --filter Conformance` and review the diff before committing.
@Suite("Conformance fixtures")
struct ConformanceTests {
    static let names = LiveOpsFixtures.names

    static let sourceDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/LiveOps/Testing/Fixtures")

    @Test("the catalogue is a sound manifest covering every window shape")
    func catalog() throws {
        let manifest = try LiveOpsFixtures.catalog()
        #expect(manifest.problems.isEmpty, "\(manifest.problems)")
        #expect(Set(manifest.windows.map(\.endPolicy)) == [.exclusive, .inclusive])
        #expect(Set(manifest.windows.map(\.whenDisabled)) == [.removed, .closed])
        #expect(Set(manifest.windows.map(\.type)) == [.instant, .day])
    }

    @Test("there are at least ten fixtures, each with an expectation")
    func inventory() throws {
        #expect(Self.names.count >= 10)
        for name in Self.names {
            #expect(throws: Never.self) { try LiveOpsFixtures.expected(name) }
        }
    }

    @Test("every hand-written probe holds", arguments: LiveOpsFixtures.names)
    func probes(name: String) throws {
        let manifest = try LiveOpsFixtures.catalog()
        let values = try LiveOpsFixtures.deliveredValues(name)
        let expected = try LiveOpsFixtures.expected(name)
        #expect(!expected.probes.isEmpty)
        for probe in expected.probes {
            let window = try #require(manifest.window(probe.window), "\(name): no window \(probe.window)")
            #expect(window.phase(at: probe.at, values: values) == probe.phase, "\(name): \(probe.window) at \(probe.at)")
        }
    }

    @Test("every recorded report matches", arguments: LiveOpsFixtures.names)
    func reports(name: String) throws {
        let manifest = try LiveOpsFixtures.catalog()
        let report = manifest.report(values: try LiveOpsFixtures.deliveredValues(name))
        var expected = try LiveOpsFixtures.expected(name)
        if ProcessInfo.processInfo.environment["FALLKIT_RECORD_FIXTURES"] == "1" {
            expected.report = report
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(expected)
            data.append(0x0A)
            try data.write(to: Self.sourceDirectory.appendingPathComponent("\(name).expected.json"))
            return
        }
        #expect(expected.report == report, "\(name): report differs; re-record only for a deliberate change")
    }
}
