import LiveOpsCore

/// Hands a ``LiveOpsStore`` the console's values. The production implementation
/// is `FirebaseLiveOpsProvider` (the only `FirebaseRemoteConfig` importer); tests
/// use `MemoryLiveOpsProvider` from LiveOpsTesting.
@MainActor
public protocol LiveOpsProviding: AnyObject {
    /// The most recently activated console values (raw strings, console-set
    /// keys only), from the SDK's persistent cache; empty until a first fetch.
    var current: LiveOpsValues { get }

    /// Fetch-and-activate. `onActivated` runs after a successful activation,
    /// whether or not anything changed; the store decides that.
    func fetch(onActivated: @escaping @MainActor () -> Void)
}
