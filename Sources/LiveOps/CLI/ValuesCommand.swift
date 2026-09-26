import LiveOpsCore

/// `liveops values`: the console as this build resolves it.
enum ValuesCommand {
    static func print(manifest: LiveOpsManifest, template: LiveOpsTemplate, output: (String) -> Void) {
        let values = template.values(forKeys: manifest.keys)
        let report = manifest.report(values: values)
        output("\(manifest.app ?? "App"): \(manifest.parameters.count) parameters, \(manifest.windows.count) windows"
            + (template.version.map { " · console version \($0)" } ?? ""))
        for problem in manifest.problems { output("⚠︎ manifest: \(problem)") }
        for key in manifest.keys where template.conditionalKeys.contains(key) {
            output("⚠︎ \(key) has conditional values; showing its default only.")
        }
        let unknown = template.values.keys.filter { !manifest.keys.contains($0) }.sorted()
        if !unknown.isEmpty {
            output("ℹ︎ \(unknown.count) console key(s) this build never reads: \(unknown.joined(separator: ", "))")
        }
        output("")
        let header = ["parameter", "type", "bundled", "console", "reading", "effective"]
        let rows = report.parameters.map { row in
            [row.name, row.type, row.bundled, row.console ?? "—", label(row.reading), row.effective]
        }
        for line in table([header] + rows) { output(line) }
        guard !report.windows.isEmpty else { return }
        output("")
        let windowRows = report.windows.map { row in
            [row.window, row.disabled ? "DISABLED (\(row.whenDisabled.rawValue))" : "\(row.start ?? "?") → \(row.end ?? "?")"]
        }
        for line in table([["window", "effective"]] + windowRows) { output(line) }
    }

    static func label(_ reading: String) -> String {
        switch reading {
        case "applied": "override"
        case "outOfRange": "OUT OF RANGE"
        case "malformed": "MALFORMED"
        default: reading
        }
    }

    /// Left-aligned columns separated by two spaces, header underlined.
    static func table(_ rows: [[String]]) -> [String] {
        guard let first = rows.first else { return [] }
        let widths = first.indices.map { column in rows.map { $0[column].count }.max() ?? 0 }
        func line(_ row: [String]) -> String {
            zip(row, widths).map { $0.padding(toLength: $1, withPad: " ", startingAt: 0) }
                .joined(separator: "  ").trimmingTrailingSpaces()
        }
        let rule = widths.map { String(repeating: "─", count: $0) }.joined(separator: "  ")
        return [line(first), rule] + rows.dropFirst().map(line)
    }
}

private extension String {
    func trimmingTrailingSpaces() -> String {
        var text = self
        while text.hasSuffix(" ") { text.removeLast() }
        return text
    }
}
