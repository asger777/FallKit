import Foundation
import LiveOpsCore
import LiveOpsStore
import LiveOpsTesting
import Testing

@MainActor
@Suite("LiveOpsStore")
struct StoreTests {
    @Test("without a provider the bundle stands and fetch does nothing")
    func noProvider() {
        let store = LiveOpsStore()
        #expect(store.values.isEmpty)
        #expect(!store.hasProvider)
        store.fetch()
        #expect(store.values.isEmpty)
        #expect(LiveOpsStore(values: ["a": "1"]).values == ["a": "1"])
    }

    @Test("attach reads the cache at once, starts one fetch and does not notify")
    func attachReadsCache() {
        let store = LiveOpsStore()
        var changes = 0
        store.onChange = { changes += 1 }
        let provider = MemoryLiveOpsProvider(current: ["feature_adventure_enabled": "false"], activation: .deferred)
        store.attach(provider: provider)
        #expect(store.hasProvider)
        #expect(store.values == ["feature_adventure_enabled": "false"])
        #expect(provider.fetchCount == 1)
        #expect(changes == 0)
    }

    @Test("an immediate activation of the cached values does not notify")
    func immediateSameValues() {
        let store = LiveOpsStore()
        var changes = 0
        store.onChange = { changes += 1 }
        store.attach(provider: MemoryLiveOpsProvider(current: ["x": "1"]))
        #expect(changes == 0)
    }

    @Test("only a changing activation notifies; a removed key returns to the bundle")
    func onlyChangesNotify() {
        let store = LiveOpsStore()
        var changes = 0
        store.onChange = { changes += 1 }
        let provider = MemoryLiveOpsProvider(activation: .deferred)
        store.attach(provider: provider)
        provider.activate([:])
        #expect(changes == 0)
        provider.activate(["ad_undo_enabled": "false"])
        #expect(changes == 1)
        #expect(!LiveOpsResolve.isEnabled(key: "ad_undo_enabled", values: store.values))
        provider.activate(["ad_undo_enabled": "false"])
        #expect(changes == 1)
        provider.activate([:])
        #expect(changes == 2)
        #expect(LiveOpsResolve.isEnabled(key: "ad_undo_enabled", values: store.values))
    }

    @Test("foreground fetch asks the provider again")
    func foregroundFetch() {
        let store = LiveOpsStore()
        let provider = MemoryLiveOpsProvider()
        store.attach(provider: provider)
        provider.current = ["x": "2"]
        store.fetch()
        #expect(provider.fetchCount == 2)
        #expect(store.values == ["x": "2"])
    }

    @Test("apply is the activation seam")
    func applySeam() {
        let store = LiveOpsStore()
        var changes = 0
        store.onChange = { changes += 1 }
        store.apply(values: [:])
        #expect(changes == 0)
        store.apply(values: ["x": "1"])
        store.apply(values: ["x": "1"])
        #expect(changes == 1)
        #expect(store.values == ["x": "1"])
    }

    @Test("start attaches what make builds, once, and only when allowed")
    func start() {
        let store = LiveOpsStore()
        var made = 0
        store.start(allowed: false) { made += 1; return MemoryLiveOpsProvider() }
        #expect(made == 0)
        #expect(!store.hasProvider)
        store.start(allowed: true) { nil }
        #expect(!store.hasProvider)
        store.start(allowed: true) { made += 1; return MemoryLiveOpsProvider(current: ["x": "1"]) }
        store.start(allowed: true) { made += 1; return MemoryLiveOpsProvider() }
        #expect(made == 1)
        #expect(store.values == ["x": "1"])
    }

    @Test("a released store ignores a late activation")
    func releasedStore() {
        let provider = MemoryLiveOpsProvider(activation: .deferred)
        var store: LiveOpsStore? = LiveOpsStore()
        store?.attach(provider: provider)
        store = nil
        provider.activate(["x": "1"])
        #expect(provider.current == ["x": "1"])
    }
}

@Suite("LiveOpsGate")
struct GateTests {
    typealias Launch = LiveOpsGate.LaunchContext

    @Test("a plain launch fetches")
    func plainLaunch() {
        #expect(LiveOpsGate.shouldFetch(Launch(arguments: ["/path/App", "-AppleLanguages", "(de)", "-FIRDebugEnabled"])))
    }

    @Test("the test host and screenshot runs never fetch")
    func testHostAndScreenshots() {
        #expect(!LiveOpsGate.shouldFetch(Launch(arguments: [], isTestHost: true)))
        #expect(!LiveOpsGate.shouldFetch(Launch(arguments: [], isScreenshotRun: true)))
    }

    @Test("exact blocked arguments", arguments: ["-demoData", "-screenshotScene", "-tokenGallery"])
    func blockedArguments(argument: String) {
        let policy = LiveOpsGate.Policy(blockedArguments: ["-demoData", "-screenshotScene", "-tokenGallery"])
        #expect(!LiveOpsGate.shouldFetch(Launch(arguments: ["/App", argument]), policy: policy))
        #expect(LiveOpsGate.shouldFetch(Launch(arguments: ["/App", argument + "X"]), policy: policy))
    }

    @Test("blocked prefixes", arguments: ["-debug.level", "-debug.autoplay", "--uitest", "--uitest-scenario=onboarding"])
    func blockedPrefixes(argument: String) {
        let policy = LiveOpsGate.Policy(blockedArgumentPrefixes: ["-debug.", "--uitest"])
        #expect(!LiveOpsGate.shouldFetch(Launch(arguments: [argument]), policy: policy))
        #expect(LiveOpsGate.shouldFetch(Launch(arguments: ["-ads.useAdMob", "1"]), policy: policy))
    }

    @Test("a blocked flag blocks as FLAG=1 in the environment or as -FLAG")
    func blockedFlags() {
        let policy = LiveOpsGate.Policy(blockedFlags: ["APP_DISABLE_ANALYTICS"])
        #expect(!LiveOpsGate.shouldFetch(Launch(arguments: [], environment: ["APP_DISABLE_ANALYTICS": "1"]), policy: policy))
        #expect(!LiveOpsGate.shouldFetch(Launch(arguments: ["-APP_DISABLE_ANALYTICS"]), policy: policy))
        #expect(LiveOpsGate.shouldFetch(Launch(arguments: [], environment: ["APP_DISABLE_ANALYTICS": "0"]), policy: policy))
        #expect(LiveOpsGate.shouldFetch(Launch(arguments: ["-APP_ANALYTICS_ON"]), policy: policy))
    }

    @Test("test-host detection is the class or the environment variable")
    func testHostDetection() {
        #expect(LiveOpsGate.isTestHost(classExists: true, environment: [:]))
        #expect(LiveOpsGate.isTestHost(classExists: false, environment: ["XCTestConfigurationFilePath": "/tmp/x"]))
        #expect(!LiveOpsGate.isTestHost(classExists: false, environment: ["HOME": "/Users/x"]))
    }

    /// `swift test` (swiftpm-testing-helper) neither loads `XCTestCase` nor sets
    /// `XCTestConfigurationFilePath`; an app's Xcode test host sets both. So this
    /// checks only that `current` reads the real process, and never prints the
    /// environment (it can hold local tokens).
    @Test("current reads this process's arguments and the union check")
    func thisProcess() {
        let launch = Launch.current(isScreenshotRun: true)
        let argumentsMatch = launch.arguments == ProcessInfo.processInfo.arguments
        let hostMatches = launch.isTestHost == LiveOpsGate.isTestHost(
            classExists: NSClassFromString("XCTestCase") != nil,
            environment: ProcessInfo.processInfo.environment
        )
        #expect(argumentsMatch)
        #expect(hostMatches)
        #expect(launch.isScreenshotRun)
        let blocked = LiveOpsGate.shouldFetch(launch)
        #expect(blocked == false)
    }
}
