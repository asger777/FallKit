import Foundation
import LiveOpsCore
import Testing

/// Strict parsers (rule #4). Inputs are taken from the five apps' parser suites.
@Suite("LiveOpsParse")
struct ParseTests {
    @Test("bool accepts six spellings, any case, trimmed", arguments: [
        ("true", true), ("TRUE", true), (" 1 ", true), ("yes", true), (" Yes ", true),
        ("false", false), ("False", false), ("0", false), ("no", false), ("NO\n", false), (" false ", false),
    ])
    func boolAccepted(text: String, expected: Bool) {
        #expect(LiveOpsParse.bool(text) == expected)
    }

    @Test("bool rejects everything else", arguments: ["", " ", "on", "off", "2", "enabled", "ja", "maybe", "nope", "tru"])
    func boolRejected(text: String) {
        #expect(LiveOpsParse.bool(text) == nil)
    }

    @Test("bool of nil is nil")
    func boolNil() {
        #expect(LiveOpsParse.bool(nil) == nil)
    }

    @Test("int inside bounds, trimmed", arguments: [("5", 5), (" 10 ", 10), ("1", 1), ("+3", 3)])
    func intAccepted(text: String, expected: Int) {
        #expect(LiveOpsParse.int(text, in: 1...10) == expected)
    }

    @Test("int outside bounds or not whole is nil, never clamped", arguments: [
        "0", "11", "50", "-3", "2.5", "three", "", " ", "5 completions", "1e1", "99999999999999999999",
    ])
    func intRejected(text: String) {
        #expect(LiveOpsParse.int(text, in: 1...10) == nil)
    }

    @Test("int of nil is nil")
    func intNil() {
        #expect(LiveOpsParse.int(nil, in: 1...10) == nil)
    }

    @Test("wholeNumber ignores bounds but still needs a whole number")
    func wholeNumber() {
        #expect(LiveOpsParse.wholeNumber(" 99 ") == 99)
        #expect(LiveOpsParse.wholeNumber("-1") == -1)
        #expect(LiveOpsParse.wholeNumber("2.5") == nil)
        #expect(LiveOpsParse.wholeNumber("") == nil)
    }

    @Test("instant accepts an offset and normalises to UTC")
    func instantOffsets() throws {
        let utc = try #require(LiveOpsParse.instant("2026-10-01T00:00:00Z"))
        #expect(utc == Date(timeIntervalSince1970: 1_790_812_800))
        #expect(LiveOpsParse.instant("2026-10-01T04:00:00+04:00") == utc)
        #expect(LiveOpsParse.instant(" 2026-10-01T00:00:00Z\n") == utc)
        #expect(LiveOpsParse.string(instant: utc) == "2026-10-01T00:00:00Z")
    }

    @Test("instant rejects date-only, epoch digits, fractional seconds and text", arguments: [
        "2026-10-01", "1790812800", "next tuesday", "", "2026-10-01T00:00:00", "2026-10-01T00:00:00.000Z",
    ])
    func instantRejected(text: String) {
        #expect(LiveOpsParse.instant(text) == nil)
    }

    @Test("instant of nil is nil")
    func instantNil() {
        #expect(LiveOpsParse.instant(nil) == nil)
    }

    @Test("day accepts strict YYYY-MM-DD, trimmed")
    func dayAccepted() {
        #expect(LiveOpsParse.day("2026-10-24")?.iso == "2026-10-24")
        #expect(LiveOpsParse.day(" 2026-10-24\n")?.iso == "2026-10-24")
        #expect(LiveOpsParse.day("2026-11-30") == LiveOpsDay(year: 2026, month: 11, day: 30))
        #expect(LiveOpsParse.day("2028-02-29") != nil)
    }

    @Test("day rejects instants, short parts, impossible dates and other formats", arguments: [
        "2026-10-2", "2026-02-30", "2026-13-01", "2026-00-10", "2027-02-29", "2026-10-24T00:00:00Z",
        "20261024", "30/11/2026", "2026--10-1", "+026-10-01", "２０２６-10-24", "", "soon",
    ])
    func dayRejected(text: String) {
        #expect(LiveOpsParse.day(text) == nil)
    }

    @Test("day of nil is nil")
    func dayNil() {
        #expect(LiveOpsParse.day(nil) == nil)
    }
}

@Suite("LiveOpsDay")
struct DayTests {
    @Test("days compare as the calendar does")
    func ordering() throws {
        let early = try #require(LiveOpsDay("2026-10-24"))
        let late = try #require(LiveOpsDay("2027-01-02"))
        #expect(early < late)
        #expect(try #require(LiveOpsDay("2026-09-30")) < early)
        #expect(early == LiveOpsDay(year: 2026, month: 10, day: 24))
    }

    @Test("the day of a date follows the calendar's time zone")
    func dayOfDate() throws {
        let instant = try #require(LiveOpsParse.instant("2026-10-24T22:30:00Z"))
        var baku = Calendar(identifier: .gregorian)
        baku.timeZone = try #require(TimeZone(identifier: "Asia/Baku"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(LiveOpsDay(date: instant, calendar: baku).iso == "2026-10-25")
        #expect(LiveOpsDay(date: instant, calendar: utc).iso == "2026-10-24")
    }

    @Test("a non-Gregorian calendar still yields the Gregorian day")
    func nonGregorian() throws {
        let instant = try #require(LiveOpsParse.instant("2026-10-24T12:00:00Z"))
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try #require(TimeZone(identifier: "UTC"))
        #expect(LiveOpsDay(date: instant, calendar: buddhist).iso == "2026-10-24")
    }

    @Test("Codable round-trips the console spelling and rejects bad text")
    func codable() throws {
        let day = try #require(LiveOpsDay("2026-03-05"))
        let data = try JSONEncoder().encode([day])
        #expect(String(decoding: data, as: UTF8.self) == #"["2026-03-05"]"#)
        #expect(try JSONDecoder().decode([LiveOpsDay].self, from: data) == [day])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([LiveOpsDay].self, from: Data(#"["2026-02-30"]"#.utf8))
        }
    }
}
