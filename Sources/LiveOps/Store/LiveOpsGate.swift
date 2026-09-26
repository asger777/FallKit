import Foundation

/// Fetch policy (rule #6): no fetch in the unit-test host, in UI-test and
/// screenshot runs, or under launch arguments whose state is synthetic.
/// Plain Debug builds do fetch: this is configuration, not measurement, and a
/// developer run is how a console value is checked before TestFlight.
public enum LiveOpsGate {
    /// What the process was launched with. ``current`` reads the real process;
    /// tests build one by hand.
    public struct LaunchContext: Sendable {
        public var arguments: [String]
        public var environment: [String: String]
        public var isTestHost: Bool
        /// Supplied by the app (Lineburst `ScreenshotState`, Wordfell `ScreenshotMode`).
        public var isScreenshotRun: Bool

        public init(arguments: [String], environment: [String: String] = [:], isTestHost: Bool = false,
                    isScreenshotRun: Bool = false) {
            self.arguments = arguments
            self.environment = environment
            self.isTestHost = isTestHost
            self.isScreenshotRun = isScreenshotRun
        }

        /// This process, with the app's own screenshot flag.
        public static func current(isScreenshotRun: Bool = false) -> LaunchContext {
            let info = ProcessInfo.processInfo
            return LaunchContext(
                arguments: info.arguments,
                environment: info.environment,
                isTestHost: LiveOpsGate.isTestHost(
                    classExists: NSClassFromString("XCTestCase") != nil,
                    environment: info.environment
                ),
                isScreenshotRun: isScreenshotRun
            )
        }
    }

    /// The app's synthetic launch modes.
    public struct Policy: Sendable {
        /// Exact arguments that block, e.g. `-demoData`, `-screenshotScene`.
        public var blockedArguments: Set<String>
        /// Argument prefixes that block, e.g. `-debug.`, `--uitest`.
        public var blockedArgumentPrefixes: [String]
        /// Flags that block when the environment has `FLAG=1` or the arguments
        /// contain `-FLAG` (Lineburst's `BLOCKRISE_DISABLE_ANALYTICS`).
        public var blockedFlags: [String]

        public init(blockedArguments: Set<String> = [], blockedArgumentPrefixes: [String] = [],
                    blockedFlags: [String] = []) {
            self.blockedArguments = blockedArguments
            self.blockedArgumentPrefixes = blockedArgumentPrefixes
            self.blockedFlags = blockedFlags
        }

        public static let none = Policy()
    }

    /// Whether this launch may build the transport and fetch.
    public static func shouldFetch(_ launch: LaunchContext, policy: Policy = .none) -> Bool {
        if launch.isTestHost || launch.isScreenshotRun { return false }
        for argument in launch.arguments {
            if policy.blockedArguments.contains(argument) { return false }
            if policy.blockedArgumentPrefixes.contains(where: { argument.hasPrefix($0) }) { return false }
        }
        for flag in policy.blockedFlags
        where launch.environment[flag] == "1" || launch.arguments.contains("-\(flag)") {
            return false
        }
        return true
    }

    /// The union of the five apps' checks: the `XCTestCase` class is loaded, or
    /// Xcode's `XCTestConfigurationFilePath` is set.
    public static func isTestHost(classExists: Bool, environment: [String: String]) -> Bool {
        classExists || environment[testConfigurationVariable] != nil
    }

    /// Set by Xcode in every test host.
    public static let testConfigurationVariable = "XCTestConfigurationFilePath"
}
