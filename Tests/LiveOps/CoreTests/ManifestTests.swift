import Foundation
import LiveOpsCore
import Testing

@Suite("LiveOpsManifest")
struct ManifestTests {
    static let window = LiveOpsManifest.Window(
        kind: .event, id: "harvest-moon", type: .instant,
        start: "2026-10-01T00:00:00Z", end: "2026-10-16T00:00:00Z",
        endPolicy: .exclusive, whenDisabled: .removed, inAppEvent: "Harvest Moon"
    )

    static func instantParameters() throws -> [LiveOpsParameter] {
        LiveOpsResolve.parameters(kind: .event, id: "harvest-moon", bundled: LiveOpsWindow(
            start: try #require(LiveOpsParse.instant("2026-10-01T00:00:00Z")),
            end: try #require(LiveOpsParse.instant("2026-10-16T00:00:00Z"))
        ))
    }

    @Test("encode then decode is lossless and stable")
    func roundTrip() throws {
        let manifest = LiveOpsManifest(
            app: "Example",
            parameters: try Self.instantParameters() + [
                .int("ad_undo_free_per_run", bounds: 1...5, bundled: 3),
                .day("season_x_start", bundled: try #require(LiveOpsDay("2026-10-15"))),
            ],
            windows: [Self.window]
        )
        let data = try manifest.encoded()
        #expect(try LiveOpsManifest(data: data) == manifest)
        #expect(try manifest.encoded() == data)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""min" : 1"#))
        #expect(text.contains(#""schemaVersion" : 1"#))
        #expect(manifest.keys.first == "event_harvest_moon_start")
    }

    @Test("an unknown schema version is rejected")
    func schema() {
        let json = #"{ "schemaVersion": 2, "parameters": [] }"#
        #expect(throws: LiveOpsManifest.Failure.unsupportedSchema(2)) { try LiveOpsManifest(data: Data(json.utf8)) }
    }

    @Test("an invalid console key is rejected and named")
    func invalidKey() {
        let json = #"{ "schemaVersion": 1, "parameters": [ { "name": "event_harvest-moon_end", "type": "bool", "bundled": "true" } ] }"#
        #expect(throws: LiveOpsManifest.Failure.invalidKey("event_harvest-moon_end")) {
            try LiveOpsManifest(data: Data(json.utf8))
        }
        #expect(LiveOpsManifest.Failure.invalidKey("k").description.contains("invalid console key: k"))
        #expect(LiveOpsManifest.Failure.unsupportedSchema(3).description.contains("schema 3"))
    }

    @Test("bad parameter types and bounds fail to decode", arguments: [
        #"{ "name": "a", "type": "float", "bundled": "1" }"#,
        #"{ "name": "a", "type": "int", "min": 5, "max": 1, "bundled": "3" }"#,
        #"{ "name": "a", "type": "int", "bundled": "3" }"#,
    ])
    func badParameters(parameter: String) {
        let json = #"{ "schemaVersion": 1, "parameters": [ \#(parameter) ] }"#
        #expect(throws: DecodingError.self) { try LiveOpsManifest(data: Data(json.utf8)) }
    }

    @Test("windows default to none")
    func noWindows() throws {
        let manifest = try LiveOpsManifest(data: Data(#"{ "schemaVersion": 1, "parameters": [] }"#.utf8))
        #expect(manifest.windows.isEmpty)
        #expect(manifest.app == nil)
    }

    @Test("problems: a window's parameters must be listed and its bounds must parse")
    func problems() throws {
        var broken = Self.window
        broken.start = "soon"
        let manifest = LiveOpsManifest(parameters: [.bool("event_harvest_moon_enabled", bundled: true)], windows: [broken])
        let found = manifest.problems
        #expect(found.contains("event/harvest-moon: parameter event_harvest_moon_start is not listed"))
        #expect(found.contains("event/harvest-moon: parameter event_harvest_moon_end is not listed"))
        #expect(found.contains("event/harvest-moon: bundled start or end is not a valid instant"))
        #expect(LiveOpsManifest(parameters: try Self.instantParameters(), windows: [Self.window]).problems.isEmpty)
    }

    @Test("window keys, effective windows and phases resolve by type")
    func windowResolution() {
        let window = Self.window
        #expect(window.key == "event/harvest-moon")
        #expect(window.enabledKey == "event_harvest_moon_enabled")
        let moved = window.effective(values: ["event_harvest_moon_end": "2026-10-20T04:00:00+04:00"])
        #expect(moved?.start == "2026-10-01T00:00:00Z")
        #expect(moved?.end == "2026-10-20T00:00:00Z")
        #expect(window.effective(values: ["event_harvest_moon_enabled": "no"]) == nil)
        #expect(window.phase(at: "2026-10-05T00:00:00Z", values: [:]) == .live)
        #expect(window.phase(at: "not a date", values: [:]) == nil)

        let day = LiveOpsManifest.Window(kind: .season, id: "s", type: .day, start: "2026-10-15", end: "2026-11-14",
                                         endPolicy: .inclusive, whenDisabled: .closed)
        #expect(day.phase(at: "2026-11-14", values: [:]) == .live)
        #expect(day.phase(at: "2026-11-14T00:00:00Z", values: [:]) == nil)
        #expect(day.phase(at: "2026-10-20", values: ["season_s_enabled": "false"]) == .over)
        #expect(day.effective(values: ["season_s_end": "2026-11-30"])?.end == "2026-11-30")

        var unparseable = day
        unparseable.end = "never"
        #expect(unparseable.effective(values: [:]) == nil)
        #expect(unparseable.phase(at: "2026-10-20", values: [:]) == nil)
        var unparseableInstant = window
        unparseableInstant.start = "never"
        #expect(unparseableInstant.effective(values: [:]) == nil)
        #expect(unparseableInstant.phase(at: "2026-10-05T00:00:00Z", values: [:]) == nil)
    }

    @Test("a report lists every parameter and window")
    func report() throws {
        let manifest = LiveOpsManifest(
            parameters: try Self.instantParameters() + [
                .bool("feature_zen_enabled", bundled: false),
                .int("ad_undo_free_per_run", bounds: 1...5, bundled: 3),
            ],
            windows: [Self.window]
        )
        let report = manifest.report(values: ["feature_zen_enabled": "true", "ad_undo_free_per_run": "9"])
        let zen = try #require(report.parameters.first { $0.name == "feature_zen_enabled" })
        #expect(zen.reading == "applied")
        #expect(zen.effective == "false")
        let undo = try #require(report.parameters.first { $0.name == "ad_undo_free_per_run" })
        #expect(undo.reading == "outOfRange")
        #expect(undo.effective == "3")
        #expect(undo.type == "int")
        #expect(report.windows == [
            LiveOpsReport.Window(window: "event/harvest-moon", start: "2026-10-01T00:00:00Z",
                                                        end: "2026-10-16T00:00:00Z", disabled: false, whenDisabled: .removed),
        ])
        #expect(manifest.window("event/harvest-moon") == Self.window)
        #expect(manifest.window("event/none") == nil)
        #expect(LiveOpsParameter.ValueType.day.code == "day")
        #expect(LiveOpsParameter.ValueType.instant.code == "instant")
        #expect(LiveOpsParameter.Reading.unset.code == "unset")
        #expect(LiveOpsParameter.Reading.malformed.code == "malformed")
    }
}

@Suite("LiveOpsDay edges")
struct DayEdgeTests {
    @Test("years outside 1...9999 and impossible components are rejected")
    func components() {
        #expect(LiveOpsDay(year: 0, month: 1, day: 1) == nil)
        #expect(LiveOpsDay(year: 10_000, month: 1, day: 1) == nil)
        #expect(LiveOpsDay(year: 2026, month: 4, day: 31) == nil)
        #expect(LiveOpsDay(year: 2026, month: 4, day: 30)?.description == "2026-04-30")
    }
}
