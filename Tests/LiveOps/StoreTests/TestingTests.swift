import LiveOpsCore
import LiveOpsStore
import LiveOpsTestFixtures
import LiveOpsTesting
import Testing

@MainActor
@Suite("MemoryLiveOpsProvider", .tags(.streakflame, .lineburst, .huefall, .boltfall, .wordfell))
struct MemoryProviderTests {
    @Test("immediate activation completes inside fetch")
    func immediate() {
        let provider = MemoryLiveOpsProvider(current: ["x": "1"])
        var calls = 0
        provider.fetch { calls += 1 }
        #expect(calls == 1)
        #expect(provider.fetchCount == 1)
        #expect(provider.pendingCount == 0)
    }

    @Test("deferred activation waits for activate and completes every pending fetch")
    func deferred() {
        let provider = MemoryLiveOpsProvider(activation: .deferred)
        var calls = 0
        provider.fetch { calls += 1 }
        provider.fetch { calls += 1 }
        #expect(calls == 0)
        #expect(provider.pendingCount == 2)
        provider.activate(["x": "2"])
        #expect(calls == 2)
        #expect(provider.current == ["x": "2"])
        #expect(provider.pendingCount == 0)
        provider.activate(["x": "3"])
        #expect(calls == 3)
    }

    @Test("activate before any fetch only changes current")
    func beforeFetch() {
        let provider = MemoryLiveOpsProvider(activation: .deferred)
        provider.activate(["x": "1"])
        #expect(provider.current == ["x": "1"])
        #expect(provider.fetchCount == 0)
    }

    @Test("never activating is a fetch that always fails")
    func never() {
        let store = LiveOpsStore()
        let provider = MemoryLiveOpsProvider(current: ["x": "1"], activation: .never)
        store.attach(provider: provider)
        provider.current = ["x": "2"]
        store.fetch()
        #expect(store.values == ["x": "1"])
        #expect(provider.fetchCount == 2)
    }
}

@Suite("Test fixtures")
struct FixtureLoaderTests {
    @Test("fixtures are bundled and listed by name")
    func names() {
        #expect(TestFixtures.names.contains("grouped"))
    }

    @Test("a fixture loads as console-set values only")
    func smoke() throws {
        let template = try TestFixtures.template("grouped")
        #expect(template.values == [
            "feature_dark_mode_enabled": "false",
            "season_summer_2026_end": "2026-11-30",
            "ad_free_hints_per_day": "1",
        ])
        #expect(template.conditionalKeys.isEmpty)
        #expect(try TestFixtures.template("conditional-only").conditionalKeys == ["feature_dark_mode_enabled", "ad_free_hints_per_day"])
        #expect(template.version == "6")
    }

    @Test("a missing fixture names itself")
    func missing() {
        #expect(throws: TestFixtures.Failure.self) { try TestFixtures.values("no-such-fixture") }
    }
}
