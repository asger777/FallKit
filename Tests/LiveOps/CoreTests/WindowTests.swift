import Foundation
import LiveOpsCore
import Testing

private let day: TimeInterval = 86_400

private func instant(_ text: String) -> Date {
    guard let date = LiveOpsParse.instant(text) else { preconditionFailure("bad instant \(text)") }
    return date
}

private func calendarDay(_ text: String) -> LiveOpsDay {
    guard let value = LiveOpsDay(text) else { preconditionFailure("bad day \(text)") }
    return value
}

/// Instant windows, end exclusive: StreakFlame, Lineburst and Boltfall suites.
@Suite("Instant windows")
struct InstantWindowTests {
    let bundled = LiveOpsWindow(start: instant("2026-10-01T00:00:00Z"), end: instant("2026-10-16T00:00:00Z"))
    let id = "harvest-moon"

    func override(_ values: LiveOpsValues) -> LiveOpsWindowOverride<Date> {
        LiveOpsResolve.windowOverride(kind: .event, id: id, values: values, parse: LiveOpsParse.instant)
    }

    func live(_ values: LiveOpsValues, at date: Date) -> Bool {
        let window = LiveOpsResolve.effective(bundled: bundled, override: override(values))
        return LiveOpsResolve.isLive(window, at: date, end: .exclusive)
    }

    @Test("bundle only: start inclusive, end exclusive")
    func bundleOnly() {
        #expect(LiveOpsResolve.effective(bundled: bundled, override: override([:])) == bundled)
        #expect(live([:], at: bundled.start))
        #expect(live([:], at: bundled.end.addingTimeInterval(-1)))
        #expect(!live([:], at: bundled.end))
        #expect(!live([:], at: bundled.start.addingTimeInterval(-1)))
        #expect(LiveOpsResolve.phase(of: bundled, at: bundled.start.addingTimeInterval(-1), end: .exclusive) == .upcoming)
        #expect(LiveOpsResolve.phase(of: bundled, at: bundled.end, end: .exclusive) == .over)
    }

    @Test("shortened: only the end moves")
    func shortened() {
        let values = ["event_harvest_moon_end": "2026-10-08T00:00:00Z"]
        #expect(override(values) == LiveOpsWindowOverride(end: instant("2026-10-08T00:00:00Z")))
        #expect(live(values, at: instant("2026-10-07T23:59:59Z")))
        #expect(!live(values, at: instant("2026-10-08T00:00:00Z")))
        #expect(!live(values, at: instant("2026-10-10T00:00:00Z")))
    }

    @Test("extended and moved earlier")
    func extendedAndMoved() {
        let values = [
            "event_harvest_moon_start": "2026-09-24T00:00:00Z",
            "event_harvest_moon_end": "2026-10-31T00:00:00+04:00",
        ]
        let window = LiveOpsResolve.effective(bundled: bundled, override: override(values))
        #expect(window == LiveOpsWindow(start: instant("2026-09-24T00:00:00Z"), end: instant("2026-10-30T20:00:00Z")))
        #expect(live(values, at: bundled.start.addingTimeInterval(-3 * day)))
        #expect(live(values, at: bundled.end.addingTimeInterval(day)))
    }

    @Test("start only: the bundled end stays")
    func startOnly() {
        let values = ["event_harvest_moon_start": "2026-09-30T00:00:00Z"]
        let window = LiveOpsResolve.effective(bundled: bundled, override: override(values))
        #expect(window?.start == instant("2026-09-30T00:00:00Z"))
        #expect(window?.end == bundled.end)
        #expect(!live(values, at: bundled.end))
    }

    @Test("disabled whatever the dates", arguments: ["false", "FALSE", "0", "no", " false "])
    func disabled(value: String) {
        let values = ["event_harvest_moon_enabled": value, "event_harvest_moon_end": "2026-12-31T00:00:00Z"]
        #expect(LiveOpsResolve.effective(bundled: bundled, override: override(values)) == nil)
        #expect(!live(values, at: bundled.start))
        #expect(LiveOpsResolve.phase(bundled: bundled, override: override(values), at: bundled.start,
                                     end: .exclusive, whenDisabled: .removed) == nil)
    }

    @Test("enabled=true does nothing")
    func enabledTrue() {
        let values = ["event_harvest_moon_enabled": "true"]
        #expect(live(values, at: bundled.start))
        #expect(!live(values, at: bundled.end))
    }

    @Test("a malformed field is dropped and its siblings stand")
    func malformedSiblings() {
        let values = [
            "event_harvest_moon_start": "next tuesday",
            "event_harvest_moon_enabled": "maybe",
            "event_harvest_moon_end": "2026-10-20T00:00:00Z",
        ]
        #expect(override(values) == LiveOpsWindowOverride(end: instant("2026-10-20T00:00:00Z")))
    }

    @Test("an override for an unknown or unsanitised id is never read")
    func unknownIds() {
        let values = [
            "event_winter_2026_start": "2026-12-01T00:00:00Z",
            "event_winter_2026_enabled": "false",
            "event_harvestmoon_enabled": "false",
            "event_harvest-moon_enabled": "false",
        ]
        let overrides = LiveOpsResolve.windowOverrides(kind: .event, ids: [id], values: values, parse: LiveOpsParse.instant)
        #expect(overrides.isEmpty)
        #expect(LiveOpsResolve.windowOverrides(kind: .event, ids: [], values: ["event_harvest_moon_enabled": "false"],
                                               parse: LiveOpsParse.instant).isEmpty)
        let disabled = LiveOpsResolve.windowOverrides(kind: .event, ids: [id], values: ["event_harvest_moon_enabled": "false"],
                                                      parse: LiveOpsParse.instant)
        #expect(disabled == [id: LiveOpsWindowOverride(enabled: false)])
    }

    @Test("an inverted window is never live; an empty one neither")
    func invertedAndEmpty() {
        let inverted = ["event_harvest_moon_end": "2026-09-01T00:00:00Z"]
        for offset in stride(from: -5.0, through: 40, by: 1) {
            #expect(!live(inverted, at: bundled.start.addingTimeInterval(offset * day)))
        }
        let empty = LiveOpsWindow(start: bundled.start, end: bundled.start)
        #expect(LiveOpsResolve.phase(of: empty, at: bundled.start, end: .exclusive) == .over)
    }

    @Test("window parameters are start, end, enabled with console spellings")
    func parameters() {
        let list = LiveOpsResolve.parameters(kind: .event, id: id, bundled: bundled)
        #expect(list.map(\.name) == ["event_harvest_moon_start", "event_harvest_moon_end", "event_harvest_moon_enabled"])
        #expect(list.map(\.bundled) == ["2026-10-01T00:00:00Z", "2026-10-16T00:00:00Z", "true"])
        #expect(list.problems.isEmpty)
    }
}

/// Day windows, end inclusive: Huefall and Wordfell suites.
@Suite("Day windows")
struct DayWindowTests {
    let bundled = LiveOpsWindow(start: calendarDay("2026-10-24"), end: calendarDay("2026-11-06"))

    func override(_ values: LiveOpsValues) -> LiveOpsWindowOverride<LiveOpsDay> {
        LiveOpsResolve.windowOverride(kind: .collection, id: "halloween", values: values, parse: LiveOpsParse.day)
    }

    func phase(_ values: LiveOpsValues, on text: String, whenDisabled: LiveOpsDisabled = .removed) -> LiveOpsPhase? {
        LiveOpsResolve.phase(bundled: bundled, override: override(values), at: calendarDay(text),
                             end: .inclusive, whenDisabled: whenDisabled)
    }

    @Test("bundle only: both ends inclusive")
    func bundleOnly() {
        #expect(phase([:], on: "2026-10-23") == .upcoming)
        #expect(phase([:], on: "2026-10-24") == .live)
        #expect(phase([:], on: "2026-11-06") == .live)
        #expect(phase([:], on: "2026-11-07") == .over)
    }

    @Test("shortened and extended")
    func shortenedAndExtended() {
        #expect(phase(["collection_halloween_end": "2026-10-31"], on: "2026-10-31") == .live)
        #expect(phase(["collection_halloween_end": "2026-10-31"], on: "2026-11-01") == .over)
        #expect(phase(["collection_halloween_end": "2026-11-13"], on: "2026-11-10") == .live)
        #expect(phase(["collection_halloween_end": "2026-11-13"], on: "2026-11-14") == .over)
    }

    @Test("moved")
    func moved() {
        let values = ["collection_halloween_start": "2026-10-17", "collection_halloween_end": "2026-10-30"]
        #expect(LiveOpsResolve.effective(bundled: bundled, override: override(values))
            == LiveOpsWindow(start: calendarDay("2026-10-17"), end: calendarDay("2026-10-30")))
    }

    @Test("an instant or short day is malformed and dropped alone")
    func malformedField() {
        let values = ["collection_halloween_start": "2026-10-2", "collection_halloween_end": "2026-11-30T00:00:00Z"]
        #expect(override(values).isEmpty)
        let mixed = ["collection_halloween_start": "2026-10-2", "collection_halloween_end": "2026-11-13"]
        #expect(override(mixed) == LiveOpsWindowOverride(end: calendarDay("2026-11-13")))
    }

    @Test("removed: a disabled window has no phase; true and malformed keep the bundle")
    func removed() {
        #expect(phase(["collection_halloween_enabled": "false"], on: "2026-10-30") == nil)
        #expect(phase(["collection_halloween_enabled": "0"], on: "2026-10-30") == nil)
        #expect(phase(["collection_halloween_enabled": "true"], on: "2026-10-30") == .live)
        #expect(phase(["collection_halloween_enabled": "off"], on: "2026-10-30") == .live)
    }

    @Test("closed (Huefall): upcoming before the start, over from the start on")
    func closed() {
        let off = ["collection_halloween_enabled": "false"]
        #expect(phase(off, on: "2026-10-01", whenDisabled: .closed) == .upcoming)
        #expect(phase(off, on: "2026-10-23", whenDisabled: .closed) == .upcoming)
        #expect(phase(off, on: "2026-10-24", whenDisabled: .closed) == .over)
        #expect(phase(off, on: "2026-10-30", whenDisabled: .closed) == .over)
        let movedOff = ["collection_halloween_enabled": "false", "collection_halloween_start": "2026-10-10"]
        #expect(phase(movedOff, on: "2026-10-12", whenDisabled: .closed) == .over)
    }

    @Test("an inverted window is never live; a one-day window is live that day")
    func invertedAndOneDay() {
        let inverted = ["collection_halloween_start": "2026-11-20"]
        for text in ["2026-10-20", "2026-10-24", "2026-11-06", "2026-11-20", "2026-11-25"] {
            #expect(phase(inverted, on: text) != .live)
        }
        #expect(phase(inverted, on: "2026-10-20") == .upcoming)
        #expect(phase(inverted, on: "2026-11-25") == .over)
        let oneDay = ["collection_halloween_end": "2026-10-24"]
        #expect(phase(oneDay, on: "2026-10-24") == .live)
        #expect(phase(oneDay, on: "2026-10-25") == .over)
    }

    @Test("day window parameters use day spellings")
    func parameters() {
        let list = LiveOpsResolve.parameters(kind: .season, id: "harvest 2026", bundled: bundled)
        #expect(list.map(\.name) == ["season_harvest_2026_start", "season_harvest_2026_end", "season_harvest_2026_enabled"])
        #expect(list.map(\.bundled) == ["2026-10-24", "2026-11-06", "true"])
        #expect(list[0].type == .day)
    }
}
