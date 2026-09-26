import LiveOpsCore
import Testing

private enum Feature: String, LiveOpsSwitch, CaseIterable {
    case adventure, cloudSync = "cloud_sync"
    var parameterName: String { LiveOpsKey.name(.feature, id: rawValue, field: "enabled") }
}

private struct Number: LiveOpsNumber {
    var parameterName = "ad_undo_free_per_run"
    var bundled = 3
    var bounds = 1...5
}

/// Rule #2 (switches only switch off) and rule #12 (bounded numbers).
@Suite("Switches and numbers", .tags(.streakflame, .lineburst, .boltfall, .huefall, .wordfell))
struct SwitchNumberTests {
    @Test("bundle only: the bundled value stands")
    func bundleOnly() {
        #expect(LiveOpsResolve.isEnabled(Feature.adventure, bundled: true, values: [:]))
        #expect(!LiveOpsResolve.isEnabled(Feature.adventure, bundled: false, values: [:]))
        #expect(LiveOpsResolve.isEnabled(key: "ad_undo_enabled", values: [:]))
    }

    @Test("every false spelling switches off", arguments: ["false", "FALSE", "0", "no", "NO", " no ", " false "])
    func switchesOff(value: String) {
        #expect(!LiveOpsResolve.isEnabled(Feature.adventure, values: ["feature_adventure_enabled": value]))
    }

    @Test("true, malformed and empty leave the bundle standing", arguments: ["true", "1", "off", "maybe", "", "nope"])
    func leavesBundle(value: String) {
        #expect(LiveOpsResolve.isEnabled(Feature.adventure, values: ["feature_adventure_enabled": value]))
    }

    @Test("a console value never switches on what the bundle has off")
    func cannotSwitchOn() {
        #expect(!LiveOpsResolve.isEnabled(Feature.adventure, bundled: false, values: ["feature_adventure_enabled": "true"]))
    }

    @Test("switches are isolated and matched exactly")
    func isolation() {
        let values: LiveOpsValues = [
            "feature_cloud_sync_enabled": "false",
            "feature_adventure_enabled ": "false",
            "feature_confetti_enabled": "false",
        ]
        #expect(LiveOpsResolve.isEnabled(Feature.adventure, values: values))
        #expect(!LiveOpsResolve.isEnabled(Feature.cloudSync, values: values))
    }

    @Test("a switch describes itself as a bool parameter")
    func switchParameter() {
        #expect(Feature.cloudSync.parameter(bundled: false) == .bool("feature_cloud_sync_enabled", bundled: false))
    }

    @Test("numbers in range apply at both bounds, trimmed", arguments: [("1", 1), (" 5 ", 5), ("4", 4)])
    func numberInRange(value: String, expected: Int) {
        #expect(LiveOpsResolve.value(Number(), values: ["ad_undo_free_per_run": value]) == expected)
    }

    @Test("numbers out of range or malformed leave the bundle, never clamped", arguments: [
        "0", "6", "-1", "50", "2.5", "three", "", "3 undos", "1e1",
    ])
    func numberFallsBack(value: String) {
        #expect(LiveOpsResolve.value(Number(), values: ["ad_undo_free_per_run": value]) == 3)
    }

    @Test("an unset number is the bundled value")
    func numberUnset() {
        #expect(LiveOpsResolve.value(Number(), values: [:]) == 3)
        #expect(Number().parameter == .int("ad_undo_free_per_run", bounds: 1...5, bundled: 3))
    }
}
