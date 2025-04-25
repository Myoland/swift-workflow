@testable import LLMFlow

import Testing
import Yams

@Test("Encode config")
func testEncodeConfig() throws {
    let config = Workflow.Config.init(
        variables: [:],
        nodes: [
            StartNode(id: "1", name: "11", input: [:]),
            EndNode(id: "2", name: "22"),
            TemplateNode(id: "3", name: "33", template: "fake template", output: "var 3")
        ],
        edges: []
    )
    
    let encoder = YAMLEncoder()
    let encoded = try encoder.encode(config)
    
    
}

@Test("Decode config")
func testDecodeConfig() throws {
    let config = Workflow.Config.init(
        variables: [:],
        nodes: [
            StartNode(id: "1", name: "11", input: [:]),
            EndNode(id: "2", name: "22"),
            TemplateNode(id: "3", name: "33", template: "fake template", output: "var 3")
        ],
        edges: []
    )
    
    let encoder = YAMLEncoder()
    let decoder = YAMLDecoder()
    
    let encoded = try encoder.encode(config)
    let decoded = try decoder.decode(Workflow.Config.self, from: encoded)
    #expect(config == decoded)
}

