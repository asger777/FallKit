import Foundation
@testable import LiveOpsCLI
import LiveOpsTestFixtures
import LiveOpsTesting
import Testing

private func run(_ arguments: [String]) -> (status: Int32, text: String) {
    var lines: [String] = []
    let status = LiveOpsCommand.run(arguments) { lines.append($0) }
    return (status, lines.joined(separator: "\n"))
}

private func fixture(_ file: String) -> String {
    TestFixtures.directory.appendingPathComponent(file).path
}

private func temporary(_ json: String) throws -> String {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("liveops-\(UUID().uuidString).json")
    try Data(json.utf8).write(to: url)
    return url.path
}

private func appEvents(state: String = "PUBLISHED", start: String, end: String, name: String = "Spring Sale") -> String {
    """
    { "data": [ { "type": "appEvents", "id": "e1", "attributes": {
        "referenceName": "\(name)", "deepLink": "app://daily", "eventState": "\(state)",
        "territorySchedules": [ { "territories": ["USA", "AZE"], "eventStart": "\(start)", "eventEnd": "\(end)" } ]
    } } ] }
    """
}

@Suite("liveops CLI")
struct CLITests {
    let manifest = fixture("catalog.manifest.json")

    @Test("help and usage errors")
    func usage() {
        #expect(run(["--help"]).status == 0)
        #expect(run(["--help"]).text.contains("check-inapp-events"))
        #expect(run(["values", "--help"]).status == 0)
        #expect(run([]).status == 2)
        #expect(run(["frobnicate", "--manifest", manifest]).status == 2)
        #expect(run(["values", "--manifest"]).status == 2)
        #expect(run(["values", "--bogus", "x"]).status == 2)
        #expect(run(["values", "--manifest", manifest]).text.contains("missing --template"))
        #expect(run(["values"]).text.contains("missing --manifest"))
        #expect(run(["values", "--manifest", "/no/such/file"]).text.contains("cannot read /no/such/file"))
    }

    @Test("values prints every parameter with its reading and effective value")
    func values() {
        let result = run(["values", "--manifest", manifest, "--template", fixture("out-of-range.template.json")])
        #expect(result.status == 0)
        #expect(result.text.contains("FallKit fixtures: 14 parameters, 3 windows"))
        let undo = result.text.split(separator: "\n").first { $0.hasPrefix("ad_free_hints_per_day ") }
        #expect(undo?.contains("OUT OF RANGE") == true)
        #expect(undo?.hasSuffix("  3") == true)
        let window = result.text.split(separator: "\n").first { $0.hasPrefix("event/spring-sale ") }
        #expect(window?.hasSuffix("  2026-10-01T00:00:00Z → 2026-10-16T00:00:00Z") == true)
    }

    @Test("values warns about conditional values, unknown keys and disabled windows")
    func warnings() {
        let conditional = run(["values", "--manifest", manifest, "--template", fixture("conditional-only.template.json")])
        #expect(conditional.text.contains("⚠︎ feature_dark_mode_enabled has conditional values"))
        let unknown = run(["values", "--manifest", manifest, "--template", fixture("unknown-ids.template.json")])
        #expect(unknown.text.contains("console key(s) this build never reads"))
        #expect(unknown.text.contains("event_autumn_2026_enabled"))
        let disabled = run(["values", "--manifest", manifest, "--template", fixture("windows-disabled.template.json")])
        #expect(disabled.text.contains("DISABLED (closed)"))
        #expect(disabled.text.contains("DISABLED (removed)"))
        let malformed = run(["values", "--manifest", manifest, "--template", fixture("malformed-values.template.json")])
        #expect(malformed.text.contains("MALFORMED"))
    }

    @Test("validate passes a sound manifest and fails a broken one")
    func validate() throws {
        #expect(run(["validate", "--manifest", manifest]).status == 0)
        let broken = try temporary("""
        { "schemaVersion": 1, "parameters": [ { "name": "ad_x", "type": "int", "min": 1, "max": 5, "bundled": "9" } ],
          "windows": [ { "kind": "event", "id": "e", "type": "instant", "start": "2026-10-01T00:00:00Z",
                         "end": "2026-10-02T00:00:00Z", "endPolicy": "exclusive", "whenDisabled": "removed" } ] }
        """)
        let result = run(["validate", "--manifest", broken])
        #expect(result.status == 1)
        #expect(result.text.contains("ad_x: bundled value \"9\""))
        #expect(result.text.contains("event/e: parameter event_e_start is not listed"))
        let invalid = try temporary(#"{ "schemaVersion": 1, "parameters": [ { "name": "bad-key", "type": "bool", "bundled": "true" } ] }"#)
        #expect(run(["validate", "--manifest", invalid]).status == 2)
        #expect(run(["validate", "--manifest", invalid]).text.contains("invalid console key: bad-key"))
    }

    @Test("check-inapp-events passes when the schedule matches the effective window")
    func inAppEventsMatch() throws {
        let events = try temporary(appEvents(start: "2026-10-01T00:00:00.000Z", end: "2026-10-16T00:00:00Z"))
        let result = run(["check-inapp-events", "--manifest", manifest, "--template", fixture("empty.template.json"),
                          "--app-events", events,
        ])
        #expect(result.status == 0, "\(result.text)")
        #expect(result.text.contains("✓ event/spring-sale ↔ \"Spring Sale\" schedule 1 (2 territories) matches"))
        #expect(result.text.contains("no In-App Event accompanies it"))
    }

    @Test("check-inapp-events fails when the console moved the window and the event did not follow")
    func inAppEventsMoved() throws {
        let events = try temporary(appEvents(start: "2026-10-01T00:00:00Z", end: "2026-10-16T00:00:00Z"))
        let result = run(["check-inapp-events", "--manifest", manifest, "--template", fixture("windows-moved.template.json"),
                          "--app-events", events,
        ])
        #expect(result.status == 1)
        #expect(result.text.contains("✗ event/spring-sale ↔ \"Spring Sale\" schedule 1"))
        #expect(result.text.contains("1 mismatch(es)"))
    }

    @Test("a disabled window needs an inactive In-App Event")
    func inAppEventsDisabled() throws {
        let template = fixture("windows-disabled.template.json")
        let live = try temporary(appEvents(start: "2026-10-01T00:00:00Z", end: "2026-10-16T00:00:00Z"))
        #expect(run(["check-inapp-events", "--manifest", manifest, "--template", template, "--app-events", live]).status == 1)
        let archived = try temporary(appEvents(state: "ARCHIVED", start: "2026-10-01T00:00:00Z", end: "2026-10-16T00:00:00Z"))
        let result = run(["check-inapp-events", "--manifest", manifest, "--template", template, "--app-events", archived])
        #expect(result.status == 0)
        #expect(result.text.contains("is disabled and In-App Event \"Spring Sale\" is ARCHIVED"))
    }

    @Test("an event without a schedule is a mismatch; missing --app-events is a usage error")
    func inAppEventsEdges() throws {
        let bare = try temporary(#"{ "data": [ { "attributes": { "referenceName": "Spring Sale", "eventState": "PUBLISHED" } } ] }"#)
        let result = run(["check-inapp-events", "--manifest", manifest, "--template", fixture("empty.template.json"),
                          "--app-events", bare,
        ])
        #expect(result.status == 1)
        #expect(result.text.contains("has no schedule"))
        #expect(run(["check-inapp-events", "--manifest", manifest, "--template", fixture("empty.template.json")]).status == 2)
    }

    @Test("matching: the manifest's reference name, else Lineburst's id rule")
    func accompanies() throws {
        let manifest = try TestFixtures.catalog()
        let event = try #require(manifest.window("event/spring-sale"))
        var byName = InAppEventAttributes(referenceName: "spring sale")
        #expect(InAppEventCheck.accompanies(byName, event))
        byName.referenceName = "Winter Lights"
        #expect(!InAppEventCheck.accompanies(byName, event))
        let season = try #require(manifest.window("season/summer_2026"))
        #expect(InAppEventCheck.accompanies(.init(referenceName: "Season SUMMER_2026"), season))
        #expect(InAppEventCheck.accompanies(.init(deepLink: "app://season/summer_2026"), season))
        #expect(!InAppEventCheck.accompanies(.init(referenceName: "Spring"), season))
    }

    @Test("a day window's event is reported, not checked")
    func dayWindowNotChecked() throws {
        let events = try temporary(appEvents(start: "2026-10-15T00:00:00Z", end: "2026-11-15T00:00:00Z", name: "Season summer_2026"))
        let result = run(["check-inapp-events", "--manifest", manifest, "--template", fixture("empty.template.json"),
                          "--app-events", events,
        ])
        #expect(result.status == 0)
        #expect(result.text.contains("day window, not checked"))
    }

    @Test("App Store Connect dates parse with or without fractional seconds")
    func ascDates() {
        #expect(InAppEventCheck.instant("2026-10-01T00:00:00.000Z") == "2026-10-01T00:00:00Z")
        #expect(InAppEventCheck.instant("2026-10-01T04:00:00+04:00") == "2026-10-01T00:00:00Z")
        #expect(InAppEventCheck.instant("soon") == nil)
        #expect(InAppEventCheck.instant(nil) == nil)
    }

    @Test("the table pads columns and underlines the header")
    func table() {
        let lines = ValuesCommand.table([["a", "bb"], ["ccc", "d"]])
        #expect(lines == ["a    bb", "───  ──", "ccc  d"])
        #expect(ValuesCommand.table([]).isEmpty)
    }
}

/// Rule: the tooling is read-only. No console writes, no App Store Connect writes.
@Suite("Tooling is read-only")
struct ReadOnlyTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func tooling() throws -> [(String, String)] {
        let cli = repo.appendingPathComponent("Sources/LiveOps/CLI")
        let files = try FileManager.default.contentsOfDirectory(atPath: cli.path).map { cli.appendingPathComponent($0) }
            + [repo.appendingPathComponent("Scripts/liveops.sh")]
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    @Test("no write verbs in the CLI or liveops.sh", arguments: [
        "remoteconfig:set", "remoteconfig:rollback", "firebase deploy", "-X POST", "-X PATCH", "-X DELETE",
        "--request", "--data", "httpMethod", "PUT ",
    ])
    func noWrites(verb: String) throws {
        for (name, text) in try Self.tooling() {
            #expect(!text.contains(verb), "\(name) contains \(verb)")
        }
    }
}
