import Foundation
import LiveOpsCore
import LiveOpsTestFixtures
import LiveOpsTesting
import Testing

/// The kit's conformance fixtures, checked through the public `LiveOpsGolden`
/// API. Probes are hand-written from Docs/behaviour.md; reports are recorded,
/// then reviewed. To re-record after a deliberate behaviour change, run
/// `FALLKIT_RECORD_FIXTURES=1 swift test --filter Conformance` and review the diff.
@Suite("Conformance fixtures")
struct ConformanceTests {
    @Test("the catalogue is a sound manifest covering every window shape")
    func catalog() throws {
        let manifest = try TestFixtures.catalog()
        #expect(manifest.problems.isEmpty, "\(manifest.problems)")
        #expect(Set(manifest.windows.map(\.endPolicy)) == [.exclusive, .inclusive])
        #expect(Set(manifest.windows.map(\.whenDisabled)) == [.removed, .closed])
        #expect(Set(manifest.windows.map(\.type)) == [.instant, .day])
    }

    @Test("there are at least ten fixtures, each with probes")
    func inventory() throws {
        #expect(TestFixtures.names.count >= 10)
        for name in TestFixtures.names {
            #expect(try !TestFixtures.expected(name).probes.isEmpty, "\(name)")
        }
    }

    @Test("every fixture passes its golden expectation", arguments: TestFixtures.names)
    func golden(name: String) throws {
        let manifest = try TestFixtures.catalog()
        let values = try TestFixtures.deliveredValues(name)
        let expected = try TestFixtures.expected(name)
        if ProcessInfo.processInfo.environment["FALLKIT_RECORD_FIXTURES"] == "1" {
            let recorded = LiveOpsGolden.recording(manifest: manifest, values: values, probes: expected.probes)
            try recorded.encoded().write(to: TestFixtures.sourceDirectory.appendingPathComponent("\(name).expected.json"))
            return
        }
        #expect(expected.report != nil, "\(name): no recorded report")
        let mismatches = LiveOpsGolden.mismatches(manifest: manifest, values: values, expected: expected)
        #expect(mismatches.isEmpty, "\(name):\n\(mismatches.joined(separator: "\n"))")
    }
}

@Suite("LiveOpsGolden")
struct GoldenTests {
    static let manifest = LiveOpsManifest(
        parameters: [
            .instant("event_sale_start", bundled: Date(timeIntervalSince1970: 1_790_812_800)),
            .instant("event_sale_end", bundled: Date(timeIntervalSince1970: 1_792_108_800)),
            .bool("event_sale_enabled", bundled: true),
            .int("ad_every_n", bounds: 1...10, bundled: 3),
        ],
        windows: [
            LiveOpsManifest.Window(kind: .event, id: "sale", type: .instant, start: "2026-10-01T00:00:00Z",
                                   end: "2026-10-16T00:00:00Z", endPolicy: .exclusive, whenDisabled: .removed),
        ]
    )

    @Test("an empty list when probes and report match")
    func matches() {
        let values: LiveOpsValues = ["ad_every_n": "4"]
        let expected = LiveOpsGolden.recording(manifest: Self.manifest, values: values, probes: [
            LiveOpsGoldenProbe(window: "event/sale", at: "2026-10-05T00:00:00Z", phase: .live),
        ])
        #expect(LiveOpsGolden.mismatches(manifest: Self.manifest, values: values, expected: expected).isEmpty)
    }

    @Test("a probe mismatch names the window, the moment and both phases")
    func probeMismatch() {
        let expected = LiveOpsGoldenExpectation(probes: [
            LiveOpsGoldenProbe(window: "event/sale", at: "2026-10-05T00:00:00Z", phase: .live),
            LiveOpsGoldenProbe(window: "event/none", at: "2026-10-05T00:00:00Z", phase: .live),
        ])
        let found = LiveOpsGolden.mismatches(manifest: Self.manifest,
                                             values: ["event_sale_end": "2026-10-02T00:00:00Z"], expected: expected)
        #expect(found == [
            "event/sale at 2026-10-05T00:00:00Z: expected live, got over",
            "probe: no window event/none in the manifest",
        ])
        let removed = LiveOpsGolden.mismatches(manifest: Self.manifest, values: ["event_sale_enabled": "false"],
                                               expected: LiveOpsGoldenExpectation(probes: [expected.probes[0]]))
        #expect(removed == ["event/sale at 2026-10-05T00:00:00Z: expected live, got removed"])
    }

    @Test("report differences, removed and new rows are listed")
    func reportMismatch() throws {
        let recorded = LiveOpsGolden.recording(manifest: Self.manifest, values: [:], probes: [])
        let changed = LiveOpsGolden.mismatches(manifest: Self.manifest, values: ["ad_every_n": "5"], expected: recorded)
        #expect(changed == ["report: ad_every_n: expected unset/3, got applied/5"])

        var grown = Self.manifest
        grown.parameters.append(.bool("feature_x_enabled", bundled: true))
        grown.windows.append(LiveOpsManifest.Window(kind: .season, id: "s", type: .day, start: "2026-10-01",
                                                    end: "2026-10-31", endPolicy: .inclusive, whenDisabled: .closed))
        let growth = LiveOpsGolden.mismatches(manifest: grown, values: [:], expected: recorded)
        #expect(growth.contains("report: parameter feature_x_enabled is new; re-record the expectation"))
        #expect(growth.contains("report: window season/s is new; re-record the expectation"))

        var shrunk = Self.manifest
        shrunk.parameters.removeLast()
        shrunk.windows = []
        let loss = LiveOpsGolden.mismatches(manifest: shrunk, values: [:], expected: recorded)
        #expect(loss.contains("report: parameter ad_every_n is no longer in the manifest"))
        #expect(loss.contains("report: window event/sale differs"))
    }

    @Test("expectations round-trip, with an explicit null for removed")
    func coding() throws {
        let expected = LiveOpsGoldenExpectation(probes: [LiveOpsGoldenProbe(window: "event/sale", at: "x", phase: nil)])
        let data = try expected.encoded()
        #expect(String(decoding: data, as: UTF8.self).contains(#""phase" : null"#))
        #expect(try LiveOpsGoldenExpectation(data: data) == expected)
    }
}
