import Foundation
import LiveOpsCore
import Testing

@Suite("LiveOpsTemplate")
struct TemplateTests {
    @Test("default values are read from parameters and groups; in-app defaults are unset")
    func parses() throws {
        let json = """
        {
          "parameters": {
            "a": { "defaultValue": { "value": "1" } },
            "b": { "defaultValue": { "useInAppDefault": true } },
            "c": { "defaultValue": { "value": "" } },
            "d": { "conditionalValues": { "ios": { "value": "x" } } }
          },
          "parameterGroups": { "G": { "parameters": { "e": { "defaultValue": { "value": "no" } } } } },
          "conditions": [ { "name": "ios", "expression": "device.os == 'ios'" } ],
          "etag": "abc"
        }
        """
        let template = try LiveOpsTemplate(data: Data(json.utf8))
        #expect(template.values == ["a": "1", "c": "", "e": "no"])
        #expect(template.conditionalKeys == ["d"])
        #expect(template.version == nil)
    }

    @Test("values(forKeys:) keeps known, non-empty keys only, as the transport does")
    func filtered() {
        let template = LiveOpsTemplate(values: ["a": "1", "c": "", "unknown": "false"])
        #expect(template.values(forKeys: ["a", "c", "missing"]) == ["a": "1"])
    }

    @Test("an empty template and a malformed file")
    func edges() throws {
        #expect(try LiveOpsTemplate(data: Data("{}".utf8)).values.isEmpty)
        #expect(throws: DecodingError.self) { try LiveOpsTemplate(data: Data("[1]".utf8)) }
    }
}
