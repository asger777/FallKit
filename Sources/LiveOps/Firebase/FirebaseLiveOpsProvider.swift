#if os(iOS) && !canImport(FirebaseRemoteConfig)
#error("LiveOpsFirebase must link FirebaseRemoteConfig on iOS; check the dependency condition in Package.swift")
#endif

#if canImport(FirebaseRemoteConfig)
import FirebaseCore
import FirebaseRemoteConfig
import Foundation
import LiveOpsCore
import LiveOpsStore

/// The Remote Config transport for every live-ops override (rule #8): the
/// **only** type in the kit that imports `FirebaseRemoteConfig`
/// (`Scripts/check-boundary.sh` fails on a second importer).
///
/// Deliberately dumb: it reads a fixed key list (the app's parameter keys) and
/// hands over the raw strings of the keys the console actually set. No parsing
/// happens here; LiveOpsCore decides what a value means, and a malformed one is
/// dropped by a tested function. A key the build does not know is never read,
/// so the console cannot create anything.
///
/// Fetch policy (rule #5): `fetchAndActivate` at launch and on foreground with
/// the SDK's default minimum interval (12 h), so most calls are served from the
/// cache; the last activated values survive offline and across launches.
/// Nothing here blocks the UI or surfaces an error. `LiveOpsGate` decides
/// whether this type is built at all. Configuration, not measurement: not gated
/// on analytics consent (rule #9).
@MainActor
public final class FirebaseLiveOpsProvider: LiveOpsProviding {
    private let keys: [String]
    private let remoteConfig: RemoteConfig
    private let log: @MainActor (String) -> Void

    /// `nil` when `configure` reports that Firebase cannot be stood up (no
    /// `GoogleService-Info.plist`): the app then resolves from the bundle, as it
    /// does offline. `log` receives one line per skip, failure or activation;
    /// the app decides whether it logs in Release.
    public static func make(
        keys: [String],
        configure: @MainActor () -> Bool = FirebaseLiveOpsProvider.configureIfNeeded,
        log: @escaping @MainActor (String) -> Void = { _ in }
    ) -> FirebaseLiveOpsProvider? {
        guard configure() else {
            log("Remote Config skipped: Firebase is not configured")
            return nil
        }
        return FirebaseLiveOpsProvider(keys: keys, log: log)
    }

    /// The standard readiness check: an app that is already configured, or a
    /// bundled `GoogleService-Info.plist` to configure from. Collection flags in
    /// `Info.plist` decide whether configuring starts any measurement.
    public static func configureIfNeeded() -> Bool {
        if FirebaseApp.app() != nil { return true }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return false }
        FirebaseApp.configure()
        return true
    }

    private init(keys: [String], log: @escaping @MainActor (String) -> Void) {
        self.keys = keys
        self.log = log
        remoteConfig = RemoteConfig.remoteConfig()
    }

    /// Console-set values only: the SDK's static default for an unset key is
    /// the empty string with a non-remote source, and that means "no override".
    public var current: LiveOpsValues {
        var values: LiveOpsValues = [:]
        for key in keys {
            let value = remoteConfig[key]
            guard value.source == .remote, !value.stringValue.isEmpty else { continue }
            values[key] = value.stringValue
        }
        return values
    }

    public func fetch(onActivated: @escaping @MainActor () -> Void) {
        remoteConfig.fetchAndActivate { status, error in
            let message = error?.localizedDescription
            Task { @MainActor in
                // Offline, throttled, or the SDK's first attempt before
                // Installations is ready (status `.error` with no error object,
                // seen on a cold launch): the cache, or the bundle, stands.
                if let message {
                    self.log("Remote Config fetch: \(message)")
                    return
                }
                guard status != .error else {
                    self.log("Remote Config fetch failed without an error object")
                    return
                }
                let source = status == .successFetchedFromRemote ? "fetched" : "pre-fetched"
                self.log("Remote Config activated (\(source))")
                onActivated()
            }
        }
    }
}
#endif
