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
        /// Supplied by the app, which knows how it runs screenshot captures.
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
        /// Environment variables that block when they hold exactly this value,
        /// e.g. `["APP_UITEST": "1"]`. For the argument form of the same switch,
        /// add it to ``blockedArguments`` as well.
        public var blockedEnvironment: [String: String]

        public init(blockedArguments: Set<String> = [], blockedArgumentPrefixes: [String] = [],
                    blockedEnvironment: [String: String] = [:]) {
            self.blockedArguments = blockedArguments
            self.blockedArgumentPrefixes = blockedArgumentPrefixes
            self.blockedEnvironment = blockedEnvironment
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
        for (key, value) in policy.blockedEnvironment where launch.environment[key] == value {
            return false
        }
        return true
    }

    /// Either XCTest signal: the `XCTestCase` class is loaded, or Xcode's
    /// `XCTestConfigurationFilePath` is set. An Xcode test host sets both.
    public static func isTestHost(classExists: Bool, environment: [String: String]) -> Bool {
        classExists || environment[testConfigurationVariable] != nil
    }

    /// Set by Xcode in every test host.
    public static let testConfigurationVariable = "XCTestConfigurationFilePath"
}
