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
import LLMFlowTestKit

@testable import LLMFlow



/// Mock Server https://github.com/kevinzhow/mockai


@Test("testWorkflowProviderTimeout")
func testWorkflowProviderTimeout() async throws {
    // This test is used to test the timeout of the LLM provider.
    let logger = Logger.testing

    try Dotenv.make()

    let openai = LLMProviderConfiguration(
        type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue,
        apiURL:
            "https://gateway.ai.cloudflare.com/v1/3450ee851bc2d21db2c2c0de5656343e/openai/openrouter"
    )

    let openaiLocal = LLMProviderConfiguration(
        type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue,
        apiURL: "http://localhost:5002/v1")

    let client = AsyncHTTPClientTransport(configuration: .init(timeout: .seconds(4)))
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(
            name: "gpt-4o-mini",
            models: [
                .init(model: .init(name: "gpt-4o-mini-timeout"), provider: openaiLocal),
                .init(model: .init(name: "gpt-4o-mini"), provider: openai),
            ])
    )
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let llmNode = LLMNode(
        id: "llm_id",
        name: nil,
        modelName: "gpt-4o-mini",
        output: nil,
        request: .init([
            "stream": true,
            "instructions": """
                be an echo server.
                before response, say 'hi [USER NAME]' first.
                what I send to you, you send back.

                the exceptions:
                1. send "ping", back "pong"
                2. send "ding", back "dang"
            """,
            "inputs": [
                [
                    "type": "text",
                    "role": "system",
                    "#content": "you are talking to {{workflow.inputs.name}}",
                ],
                [
                    "type": "text",
                    "role": "user",
                    "$content": ["workflow", "inputs", "message"],
                ],
            ],
        ]))

    let endNode = EndNode(id: UUID().uuidString, name: nil)
    let locator = DummySimpleLocater(client, solver)

    let workflow = Workflow(
        nodes: [
            startNode.id: startNode,
            llmNode.id: llmNode,
            endNode.id: endNode,
        ],
        flows: [
            startNode.id: [.init(from: startNode.id, to: llmNode.id, condition: nil)],
            llmNode.id: [.init(from: llmNode.id, to: endNode.id, condition: nil)],
        ], startNodeID: startNode.id, locator: locator)

    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping",
        ]

        let context = Context()
        let states = try workflow.run(inputs: inputs, context: context)
        for try await state in states {
            logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
        }
        let nodeResult = states.context[path: "llm_id", ContextStoreKey.WorkflowNodeRunResultKey]
        let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
        let usage = response.usage
        let content = response.items.first?.message?.content?.first?.text?.content
        logger.info("[*] \(content ?? "nil")")
        logger.info("[*] \(String(describing: usage))")
    } catch {
        Issue.record("Unexpected \(error)")
    }
}
