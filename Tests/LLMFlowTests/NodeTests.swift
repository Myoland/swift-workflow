@testable import LLMFlow

import Testing
import Yams

@Test("testEncodeNode", arguments: [
    (
        StartNode(id: "1", name: "11", inputs: [:]) as any LLMFlow.Node,
        """
        id: '1'
        name: '11'
        type: START
        inputs: {}
        """
    ), (
        EndNode(id: "2", name: "22"),
        """
        id: '2'
        name: '22'
        type: END
        """
    ), (
        TemplateNode(id: "3", name: "33", template: "fake template"),
        """
        id: '3'
        name: '33'
        type: TEMPLATE
        template: fake template
        """
    ), 
    // (
    //     LLMNode(id: "5", name: "55", request: "fake template", response: "var 5"),
    //     """
    //     id: '5'
    //     name: '55'
    //     type: LLM
    //     request: fake template
    //     response: var 5
    //     """
    // )
])
func testEncodeNode(_ node: any LLMFlow.Node, expect: String) throws {
    let encoder = YAMLEncoder()
    let encoded = try encoder.encode(node)
    #expect(encoded.trimmingCharacters(in: .whitespacesAndNewlines) == expect)
}


@Test("testDecodeNode", arguments: [
    StartNode(id: "1", name: "11", inputs: [:]) as any LLMFlow.Node,
    EndNode(id: "2", name: "22"),
    TemplateNode(id: "3", name: "33", template: "fake template"),
    // LLMNode(id: "5", name: "55", request: "fake template", response: "var 5"),
])
func testDecodeNode(_ node: any LLMFlow.Node) throws {
    
    let encoder = YAMLEncoder()
    let decoder = YAMLDecoder()
    
    let encoded = try encoder.encode(node)
    
    switch node {
    case let node as StartNode:
        let decoded = try decoder.decode(StartNode.self, from: encoded)
        #expect(node == decoded)
    case let node as EndNode:
        let decoded = try decoder.decode(EndNode.self, from: encoded)
        #expect(node == decoded)
    case let node as TemplateNode:
        let decoded = try decoder.decode(TemplateNode.self, from: encoded)
        #expect(node == decoded)
    case let node as LLMNode:
        let decoded = try decoder.decode(LLMNode.self, from: encoded)
        #expect(node == decoded)
    default:
        Issue.record("Unknown Node Type")
    }
}
