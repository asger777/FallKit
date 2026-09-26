import Foundation
import LiveOpsCore

/// App Store Connect `GET /v1/apps/<id>/appEvents`, reduced to what the check reads.
struct InAppEvents: Decodable {
    var data: [InAppEvent]

    init(data: Data) throws {
        self = try JSONDecoder().decode(InAppEvents.self, from: data)
    }
}

struct InAppEvent: Decodable {
    var attributes: InAppEventAttributes
}

struct InAppEventAttributes: Decodable {
    var referenceName: String?
    var deepLink: String?
    var eventState: String?
    var territorySchedules: [InAppEventSchedule]?

    init(referenceName: String? = nil, deepLink: String? = nil, eventState: String? = nil,
         territorySchedules: [InAppEventSchedule]? = nil) {
        self.referenceName = referenceName
        self.deepLink = deepLink
        self.eventState = eventState
        self.territorySchedules = territorySchedules
    }
}

struct InAppEventSchedule: Decodable {
    var territories: [String]?
    var eventStart: String?
    var eventEnd: String?
}

/// `liveops check-inapp-events` (rule #11): every In-App Event that accompanies
/// a window must match the window's effective dates; a disabled window's event
/// must be in a state that can no longer reach a player.
enum InAppEventCheck {
    /// States in which an In-App Event can no longer reach a player.
    static let inactiveStates: Set<String> = ["ARCHIVED", "REJECTED", "DRAFT", "PAST"]

    static func run(manifest: LiveOpsManifest, template: LiveOpsTemplate, events: InAppEvents,
                    output: (String) -> Void) -> Int32 {
        let values = template.values(forKeys: manifest.keys)
        var mismatches = 0
        for window in manifest.windows {
            for key in [window.startKey, window.endKey, window.enabledKey] where template.conditionalKeys.contains(key) {
                output("⚠︎ \(key) has conditional values; checking against its default only.")
            }
        }
        output("App Store In-App Events: \(events.data.count)")
        for window in manifest.windows {
            mismatches += check(window, values: values, events: events.data, output: output)
        }
        output(mismatches == 0 ? "OK" : "\(mismatches) mismatch(es)")
        return mismatches == 0 ? 0 : 1
    }

    private static func check(_ window: LiveOpsManifest.Window, values: LiveOpsValues, events: [InAppEvent],
                              output: (String) -> Void) -> Int {
        let effective = window.effective(values: values)
        let text = effective.map { "\($0.start) → \($0.end)" } ?? "DISABLED"
        let accompanying = events.filter { accompanies($0.attributes, window) }
        guard !accompanying.isEmpty else {
            output("✓ \(window.key) (effective \(text)): no In-App Event accompanies it.")
            return 0
        }
        var mismatches = 0
        for event in accompanying {
            let name = event.attributes.referenceName ?? "?"
            let state = event.attributes.eventState ?? "?"
            guard let effective else {
                if inactiveStates.contains(state) {
                    output("✓ \(window.key) is disabled and In-App Event \"\(name)\" is \(state).")
                } else {
                    output("✗ \(window.key) is DISABLED but In-App Event \"\(name)\" is \(state).")
                    mismatches += 1
                }
                continue
            }
            guard window.type == .instant else {
                output("ℹ︎ \(window.key) ↔ \"\(name)\": day window, not checked (no time-zone rule for In-App Event dates).")
                continue
            }
            let schedules = event.attributes.territorySchedules ?? []
            if schedules.isEmpty {
                output("✗ In-App Event \"\(name)\" accompanies \(window.key) but has no schedule.")
                mismatches += 1
            }
            for (index, schedule) in schedules.enumerated() {
                let start = instant(schedule.eventStart)
                let end = instant(schedule.eventEnd)
                let territories = schedule.territories?.count ?? 0
                if start == effective.start, end == effective.end {
                    output("✓ \(window.key) ↔ \"\(name)\" schedule \(index + 1) (\(territories) territories) matches \(text).")
                } else {
                    output("✗ \(window.key) ↔ \"\(name)\" schedule \(index + 1): In-App Event \(start ?? "—") → \(end ?? "—"),"
                        + " effective window \(text).")
                    mismatches += 1
                }
            }
        }
        return mismatches
    }

    /// The manifest's `inAppEvent` reference name, or, without one, Lineburst's
    /// rule: the reference name or deep link mentions the window id, as written
    /// or sanitised.
    static func accompanies(_ attributes: InAppEventAttributes, _ window: LiveOpsManifest.Window) -> Bool {
        if let reference = window.inAppEvent {
            return attributes.referenceName?.caseInsensitiveCompare(reference) == .orderedSame
        }
        let haystack = [attributes.referenceName, attributes.deepLink].compactMap { $0 }.joined(separator: " ").lowercased()
        return [window.id, LiveOpsKey.sanitise(window.id)].contains { haystack.contains($0.lowercased()) }
    }

    /// An App Store Connect date, with or without fractional seconds, spelled
    /// the way the manifest spells instants (UTC, `Z`).
    static func instant(_ text: String?) -> String? {
        guard let text else { return nil }
        if let date = LiveOpsParse.instant(text) { return LiveOpsParse.string(instant: date) }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text).map { LiveOpsParse.string(instant: $0) }
    }
}
