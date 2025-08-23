import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import GPT
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import Yams
import Logging

@testable import LLMFlow


@Test("testWorkflowRun")
func testWorkflowRun() async throws {
    let logger = Logger.testing

    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let outputKey = "ultimate"
    let llmNode  = LLMNode(
        id: UUID().uuidString,
        name: nil,
        modelName: "gpt-4o-mini",
        output: outputKey,
        request: .init([
            "stream": false,
            "instructions": """
                be an echo server.
                before response, say 'hi [USER NAME]' first.
                what I send to you, you send back.

                the exceptions:
                1. send "ping", back "pong"
                2. send "ding", back "dang"
            """,
            "inputs": [[
                "type": "text",
                "role": "system",
                "#content": "you are talking to {{workflow.inputs.name}}"
            ], [
                "type": "text",
                "role": "user",
                "$content": ["workflow", "inputs", "message"],
            ]]
        ]))

    let endNode = EndNode(id: UUID().uuidString, name: nil)
    let locator = DummySimpleLocater(client, solver)

    let workflow = Workflow(nodes: [
        startNode.id : startNode,
        llmNode.id : llmNode,
        endNode.id : endNode
    ], flows: [
        startNode.id : [.init(from: startNode.id, to: llmNode.id, condition: nil)],
        llmNode.id : [.init(from: llmNode.id, to: endNode.id, condition: nil)],
    ], startNodeID: startNode.id, locator: locator)


    let inputs: [String: FlowData] = [
        "name": "John",
        "message": "ping"
    ]

    let context = Context()
    let states = try workflow.run(inputs: inputs, context: context)
    for try await state in states {
        logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
    }

    print(context.store.withLock({ $0 }))
    let response = context["workflow.output.\(outputKey).items.0.content.0.content"] as? String
    #expect(response?.contains("pong") ?? false)
}
