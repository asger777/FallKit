import Foundation
import LiveOpsCore
import Testing

/// Readings (rule #4, #12). Cases from S, L, B, H and W `parameterReadings…` tests.
@Suite("LiveOpsParameter", .tags(.streakflame, .lineburst, .boltfall, .huefall, .wordfell))
struct ParameterTests {
    @Test("an int parameter reads unset, applied, out of range and malformed")
    func intReadings() {
        let count = LiveOpsParameter.int("ad_undo_free_per_run", bounds: 1...5, bundled: 3)
        #expect(count.bundled == "3")
        #expect(count.read(nil) == .unset)
        #expect(count.read("2") == .applied("2"))
        #expect(count.read(" 4 ") == .applied("4"))
        #expect(count.read("9") == .outOfRange(1...5))
        #expect(count.read("0") == .outOfRange(1...5))
        #expect(count.read("-1") == .outOfRange(1...5))
        #expect(count.read("two") == .malformed)
        #expect(count.read("2.5") == .malformed)
        #expect(count.read("") == .malformed)
        #expect(count.read("   ") == .malformed)
    }

    @Test("a bool parameter normalises its spelling")
    func boolReadings() {
        let flag = LiveOpsParameter.bool("feature_adventure_enabled", bundled: true)
        #expect(flag.bundled == "true")
        #expect(flag.read("NO") == .applied("false"))
        #expect(flag.read("YES") == .applied("true"))
        #expect(flag.read("1") == .applied("true"))
        #expect(flag.read("nah") == .malformed)
        #expect(flag.read("nope") == .malformed)
    }

    @Test("an instant parameter normalises to UTC")
    func instantReadings() throws {
        let start = try #require(LiveOpsParse.instant("2027-01-01T00:00:00Z"))
        let parameter = LiveOpsParameter.instant("event_new_year_2027_start", bundled: start)
        #expect(parameter.bundled == "2027-01-01T00:00:00Z")
        #expect(parameter.read("2027-01-01T04:00:00+04:00") == .applied("2027-01-01T00:00:00Z"))
        #expect(parameter.read("soon") == .malformed)
        #expect(parameter.read("2027-01-01") == .malformed)
    }

    @Test("a day parameter reads trimmed days only")
    func dayReadings() throws {
        let parameter = LiveOpsParameter.day("season_harvest_2026_start", bundled: try #require(LiveOpsDay("2026-10-15")))
        #expect(parameter.bundled == "2026-10-15")
        #expect(parameter.type == .day)
        #expect(parameter.read(" 2026-10-01 ") == .applied("2026-10-01"))
        #expect(parameter.read("2026-11-30T00:00:00Z") == .malformed)
        #expect(parameter.read("soon") == .malformed)
    }

    @Test("isMalformed covers malformed and out of range; appliedValue only applied")
    func readingHelpers() {
        #expect(LiveOpsParameter.Reading.malformed.isMalformed)
        #expect(LiveOpsParameter.Reading.outOfRange(1...3).isMalformed)
        #expect(!LiveOpsParameter.Reading.unset.isMalformed)
        #expect(!LiveOpsParameter.Reading.applied("1").isMalformed)
        #expect(LiveOpsParameter.Reading.applied("x").appliedValue == "x")
        #expect(LiveOpsParameter.Reading.unset.appliedValue == nil)
    }

    @Test("read(in:) looks up the parameter's own key only")
    func readInValues() {
        let flag = LiveOpsParameter.bool("feature_a_enabled", bundled: true)
        let values: LiveOpsValues = ["feature_b_enabled": "false", "feature_a_enabled ": "false"]
        #expect(flag.read(in: values) == .unset)
        #expect(flag.read(in: ["feature_a_enabled": "0"]) == .applied("false"))
    }

    @Test("keys keep order and drop duplicates")
    func keys() {
        let list: [LiveOpsParameter] = [
            .bool("feature_b_enabled", bundled: true),
            .bool("feature_a_enabled", bundled: true),
            .bool("feature_b_enabled", bundled: true),
        ]
        #expect(list.keys == ["feature_b_enabled", "feature_a_enabled"])
    }

    @Test("problems finds bad names, duplicates, long keys and bundled values outside bounds")
    func problems() {
        let long = "k" + String(repeating: "x", count: LiveOpsParameter.maximumKeyLength)
        let list: [LiveOpsParameter] = [
            .bool("feature_ok_enabled", bundled: true),
            .bool("event_harvest-moon_end", bundled: true),
            .int("ad_every_n", bounds: 1...10, bundled: 11),
            .bool("feature_ok_enabled", bundled: false),
            .bool(long, bundled: true),
            LiveOpsParameter(name: "promo_x_enabled", type: .bool, bundled: "maybe"),
        ]
        let found = list.problems
        #expect(found.count == 5)
        #expect(found.contains { $0.hasPrefix("event_harvest-moon_end: not a valid") })
        #expect(found.contains { $0.hasPrefix("ad_every_n: bundled value \"11\"") })
        #expect(found.contains { $0.hasPrefix("feature_ok_enabled: listed twice") })
        #expect(found.contains { $0.contains("longer than 256") })
        #expect(found.contains { $0.hasPrefix("promo_x_enabled: bundled value") })
        #expect([LiveOpsParameter.int("ad_ok", bounds: 1...5, bundled: 5)].problems.isEmpty)
    }
}
