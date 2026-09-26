import Foundation
import LiveOpsCore

/// `liveops`: read-only live-ops tooling driven by an app's
/// `liveops-manifest.json` (Docs/manifest.md). It never writes to a Firebase
/// console or to App Store Connect; `Scripts/liveops.sh` fetches the inputs.
enum LiveOpsCommand {
    static let usage = """
    usage: liveops <command> [options]

    Commands:
      values              Print every parameter and window the build reads, with the
                          console value, its reading and the effective value.
      check-inapp-events  Check that every App Store In-App Event matches the effective
                          window it accompanies. Exits 1 on a mismatch.
      validate            Check a manifest (key names, duplicates, bundled values). Exits 1
                          when it has problems.

    Options:
      --manifest <file>     The app's liveops-manifest.json (all commands)
      --template <file>     A Remote Config template from `firebase remoteconfig:get`
                            (values, check-inapp-events)
      --app-events <file>   GET /v1/apps/<id>/appEvents from App Store Connect
                            (check-inapp-events)
      -h, --help            Show this help

    Exit status: 0 OK · 1 mismatch or invalid manifest · 2 usage or input error
    """

    enum Failure: Error, CustomStringConvertible {
        case usage(String)
        case input(String)

        var description: String {
            switch self {
            case let .usage(message), let .input(message): message
            }
        }
    }

    /// Runs one invocation; `output` receives every line. Returns the exit status.
    static func run(_ arguments: [String], output: (String) -> Void) -> Int32 {
        do {
            return try dispatch(arguments, output: output)
        } catch let failure as Failure {
            output("liveops: \(failure)")
            if case .usage = failure { output(usage) }
            return 2
        } catch {
            output("liveops: \(error)")
            return 2
        }
    }

    private static func dispatch(_ arguments: [String], output: (String) -> Void) throws -> Int32 {
        guard let command = arguments.first else { throw Failure.usage("missing command") }
        if command == "-h" || command == "--help" || command == "help" {
            output(usage)
            return 0
        }
        let options = try parse(Array(arguments.dropFirst()))
        if options["help"] != nil {
            output(usage)
            return 0
        }
        let manifest = try loadManifest(options)
        switch command {
        case "values":
            let template = try loadTemplate(options)
            ValuesCommand.print(manifest: manifest, template: template, output: output)
            return 0
        case "check-inapp-events":
            let template = try loadTemplate(options)
            guard let path = options["app-events"] else { throw Failure.usage("check-inapp-events needs --app-events <file>") }
            let events = try InAppEvents(data: read(path))
            return InAppEventCheck.run(manifest: manifest, template: template, events: events, output: output)
        case "validate":
            let problems = manifest.problems
            for problem in problems { output("✗ \(problem)") }
            output(problems.isEmpty ? "OK: \(manifest.parameters.count) parameters, \(manifest.windows.count) windows"
                : "\(problems.count) problem(s)")
            return problems.isEmpty ? 0 : 1
        default:
            throw Failure.usage("unknown command \(command)")
        }
    }

    static func parse(_ arguments: [String]) throws -> [String: String] {
        var options: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                options["help"] = ""
            case "--manifest", "--template", "--app-events":
                guard index + 1 < arguments.count else { throw Failure.usage("\(argument) needs a file") }
                options[String(argument.dropFirst(2))] = arguments[index + 1]
                index += 1
            default:
                throw Failure.usage("unknown option \(argument)")
            }
            index += 1
        }
        return options
    }

    private static func loadManifest(_ options: [String: String]) throws -> LiveOpsManifest {
        guard let path = options["manifest"] else { throw Failure.usage("missing --manifest <file>") }
        do {
            return try LiveOpsManifest(data: read(path))
        } catch let failure as LiveOpsManifest.Failure {
            throw Failure.input("\(path): \(failure)")
        }
    }

    private static func loadTemplate(_ options: [String: String]) throws -> LiveOpsTemplate {
        guard let path = options["template"] else { throw Failure.usage("missing --template <file>") }
        return try LiveOpsTemplate(data: read(path))
    }

    private static func read(_ path: String) throws -> Data {
        guard let data = FileManager.default.contents(atPath: path) else { throw Failure.input("cannot read \(path)") }
        return data
    }
}
