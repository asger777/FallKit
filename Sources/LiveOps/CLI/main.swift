import Foundation

let status = LiveOpsCommand.run(Array(CommandLine.arguments.dropFirst())) { print($0) }
exit(status)
