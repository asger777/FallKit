// The README quick start, copied verbatim by check.sh's guard: if this file and
// README.md drift apart, check.sh fails. Compiling it is the point.
import Foundation
import SwiftUI
import LiveOpsCore
import LiveOpsFirebase
import LiveOpsStore

enum Feature: String, LiveOpsSwitch, CaseIterable {
    case adventure
    var parameterName: String { LiveOpsKey.name(.feature, id: rawValue, field: "enabled") }
}

struct FreeUndos: LiveOpsNumber {
    let parameterName = "ad_undo_free_per_run"
    let bundled = 3
    let bounds = 1...5
}

@MainActor
final class LiveOps {
    static let shared = LiveOps()
    let store = LiveOpsStore()

    static var parameters: [LiveOpsParameter] {
        Feature.allCases.map { $0.parameter() } + [FreeUndos().parameter]
    }

    /// Launch: attach the transport unless this is a test host or a synthetic run.
    func start() {
        let allowed = LiveOpsGate.shouldFetch(.current(), policy: .init(blockedArgumentPrefixes: ["-debug."]))
        store.start(allowed: allowed) { FirebaseLiveOpsProvider.make(keys: Self.parameters.keys) }
    }

    func isEnabled(_ feature: Feature) -> Bool { LiveOpsResolve.isEnabled(feature, values: store.values) }
    var freeUndos: Int { LiveOpsResolve.value(FreeUndos(), values: store.values) }
}
// On foreground: LiveOps.shared.store.fetch()

@main
struct ConsumerCheckApp: App {
    init() { LiveOps.shared.start() }

    var body: some Scene {
        WindowGroup { Text(summary) }
    }

    @MainActor var summary: String {
        let store = LiveOps.shared.store
        let now = Date()
        let eventStart = now, eventEnd = now.addingTimeInterval(86_400)
        let bundled = LiveOpsWindow(start: eventStart, end: eventEnd)            // Date, or LiveOpsDay for day windows
        let override = LiveOpsResolve.windowOverride(kind: .event, id: "spring-sale",
                                                     values: store.values, parse: LiveOpsParse.instant)
        let phase = LiveOpsResolve.phase(bundled: bundled, override: override, at: now,
                                         end: .exclusive, whenDisabled: .removed)  // .upcoming / .live / .over / nil
        return "adventure \(LiveOps.shared.isEnabled(.adventure)) · undos \(LiveOps.shared.freeUndos) · \(String(describing: phase))"
    }
}
