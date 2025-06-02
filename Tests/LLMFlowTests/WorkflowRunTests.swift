import AsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit

@testable import LLMFlow


@Test("testWorkflowRun")
func testWorkflowRun() async throws {


    try Dotenv.make()

    let client = HTTPClient()
    let solver = DummyLLMProviderSolver(
        "test_openai",
        .OpenAI(.init(apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com"))
    )

    let startNode = StartNode(id: UUID().uuidString, name: nil, input: [
        "message": .single(.string)
    ])

    let templateNode = TemplateNode(
        id: UUID().uuidString,
        name: nil,
        template: Template(content: """

        """),
        output: ""
    )

    let llmNode  = LLMNode(id: UUID().uuidString, name: nil, modelName: "test_openai", request: .init(body: [:]))

    let endNode = EndNode(id: UUID().uuidString, name: nil)

    var context = Context(locater: DummySimpleLocater(client, solver))


    let workflow = Workflow(nodes: [
        startNode.id : startNode,
        templateNode.id : templateNode,
        llmNode.id : llmNode,
        endNode.id : endNode
    ], flows: [
        startNode.id : [.init(from: startNode.id, to: templateNode.id, condition: nil)],
        templateNode.id : [.init(from: templateNode.id, to: llmNode.id, condition: nil)],
        llmNode.id : [.init(from: llmNode.id, to: endNode.id, condition: nil)],
    ], startNodeID: startNode.id)


    let output = try await workflow.run(context: &context)



}
