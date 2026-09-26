import LiveOpsCore
import Observation

/// The live-ops values an app reads (rule #1): the bundle until an override has
/// ever been fetched, then the most recently activated console values, offline
/// included. `values` is observable, so a view whose body read a resolved value
/// re-renders when an activation changes it; consumers that cache hang off
/// ``onChange``.
///
/// Not a singleton: each app keeps its own `shared` and its own resolved
/// accessors over ``values``.
@Observable
@MainActor
public final class LiveOpsStore {
    public private(set) var values: LiveOpsValues
    @ObservationIgnored private var provider: (any LiveOpsProviding)?

    /// Runs after an activation that changed ``values``: never for one that did
    /// not, and never for the cached read at attach, which precedes every reader.
    @ObservationIgnored public var onChange: (@MainActor () -> Void)?

    public init(values: LiveOpsValues = [:]) {
        self.values = values
    }

    public var hasProvider: Bool { provider != nil }

    /// Launch: when `allowed` (see ``LiveOpsGate``) and no provider is attached
    /// yet, build one and attach it. Idempotent. `make` returns `nil` when the
    /// transport cannot exist (no Firebase configuration); the bundle stands.
    public func start(allowed: Bool, make: () -> (any LiveOpsProviding)?) {
        guard provider == nil, allowed, let made = make() else { return }
        attach(provider: made)
    }

    /// Reads the provider's cached values synchronously, before any reader,
    /// without notifying, and starts a fetch.
    public func attach(provider: any LiveOpsProviding) {
        self.provider = provider
        values = provider.current
        fetch()
    }

    /// Launch and foreground. Never blocks, never surfaces an error; the SDK's
    /// default minimum interval decides whether it touches the network. A no-op
    /// without a provider.
    public func fetch() {
        provider?.fetch { [weak self] in
            guard let self, let provider = self.provider else { return }
            self.apply(values: provider.current)
        }
    }

    /// Test seam and debugging: replace the values exactly as an activation would.
    public func apply(values: LiveOpsValues) {
        guard values != self.values else { return }
        self.values = values
        onChange?()
    }
}
