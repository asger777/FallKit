import LiveOpsCore
import LiveOpsStore

/// A provider for tests: no SDK, no network. Activation can complete inside
/// `fetch`, or later when the test calls ``activate(_:)``.
@MainActor
public final class MemoryLiveOpsProvider: LiveOpsProviding {
    public enum Activation: Sendable {
        /// `onActivated` runs inside `fetch`.
        case immediate
        /// `onActivated` waits for ``activate(_:)``.
        case deferred
        /// `onActivated` never runs: a fetch that always fails.
        case never
    }

    public var current: LiveOpsValues
    public var activation: Activation
    public private(set) var fetchCount = 0
    private var pending: [@MainActor () -> Void] = []
    private var last: (@MainActor () -> Void)?

    public init(current: LiveOpsValues = [:], activation: Activation = .immediate) {
        self.current = current
        self.activation = activation
    }

    public func fetch(onActivated: @escaping @MainActor () -> Void) {
        fetchCount += 1
        last = onActivated
        switch activation {
        case .immediate: onActivated()
        case .deferred: pending.append(onActivated)
        case .never: break
        }
    }

    /// Delivers `values` as the console's latest activation: completes every
    /// pending fetch, or, when none is pending, re-delivers to the most recent
    /// fetch's callback, so every `activate` reaches the store once a fetch has
    /// started. Before any fetch it only changes ``current``.
    public func activate(_ values: LiveOpsValues) {
        current = values
        guard !pending.isEmpty else {
            last?()
            return
        }
        let waiting = pending
        pending = []
        for callback in waiting { callback() }
    }

    /// Fetches waiting for ``activate(_:)``.
    public var pendingCount: Int { pending.count }
}
