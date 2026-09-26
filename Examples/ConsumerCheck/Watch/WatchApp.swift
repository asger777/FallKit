// A watchOS target that links LiveOpsCore only: no Firebase, no Observation.
import LiveOpsCore
import SwiftUI

@main
struct ConsumerCheckWatchApp: App {
    var body: some Scene {
        WindowGroup { Text(phase) }
    }

    var phase: String {
        guard let start = LiveOpsDay("2026-10-24"), let end = LiveOpsDay("2026-11-06") else { return "?" }
        let today = LiveOpsDay(date: Date(), calendar: .current)
        return LiveOpsResolve.phase(of: LiveOpsWindow(start: start, end: end), at: today, end: .inclusive).rawValue
    }
}
