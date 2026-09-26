import Foundation

/// A Remote Config template as `firebase remoteconfig:get` writes it, reduced to
/// what an app would receive with no condition matching: each parameter's
/// console-set default value. `useInAppDefault` means "unset". Parameters inside
/// `parameterGroups` count the same as top-level ones. Conditional values are
/// listed separately; they are never folded into ``values``.
public struct LiveOpsTemplate: Sendable, Equatable {
    /// Console-set default values, keyed by parameter name.
    public let values: LiveOpsValues
    /// Parameter names that carry conditional values (reported, not applied).
    public let conditionalKeys: Set<String>
    /// The template's version number, when the file has one.
    public let version: String?

    public init(values: LiveOpsValues, conditionalKeys: Set<String> = [], version: String? = nil) {
        self.values = values
        self.conditionalKeys = conditionalKeys
        self.version = version
    }

    public init(data: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        var values: LiveOpsValues = [:]
        var conditional = Set<String>()
        let groups = (file.parameterGroups ?? [:]).values.map { $0.parameters ?? [:] }
        for parameters in [file.parameters ?? [:]] + groups {
            for (name, parameter) in parameters {
                if let value = parameter.defaultValue?.value, parameter.defaultValue?.useInAppDefault != true {
                    values[name] = value
                }
                if !(parameter.conditionalValues ?? [:]).isEmpty { conditional.insert(name) }
            }
        }
        self.init(values: values, conditionalKeys: conditional, version: file.version?.versionNumber)
    }

    /// The values an app with this key list would see: known keys only, empty
    /// strings dropped, exactly as the transport filters them.
    public func values(forKeys keys: [String]) -> LiveOpsValues {
        var result: LiveOpsValues = [:]
        for key in keys {
            if let value = values[key], !value.isEmpty { result[key] = value }
        }
        return result
    }

    private struct File: Decodable {
        var parameters: [String: Parameter]?
        var parameterGroups: [String: Group]?
        var version: Version?
    }

    private struct Group: Decodable {
        var parameters: [String: Parameter]?
    }

    private struct Parameter: Decodable {
        var defaultValue: Value?
        var conditionalValues: [String: Value]?
    }

    private struct Value: Decodable {
        var value: String?
        var useInAppDefault: Bool?
    }

    private struct Version: Decodable {
        var versionNumber: String?
    }
}
