import AsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import Yams

@testable import LLMFlow


@Test("testWorkflowRun")
func testWorkflowRun() async throws {

    try Dotenv.make()

    let openai = LLMProvider(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let client = HTTPClient()
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", type: .OpenAI, models: [.init(name: "gpt-4o-mini", provider: openai)])
    )
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let llmNode  = LLMNode(
        id: UUID().uuidString,
        name: nil,
        modelName: "gpt-4o-mini",
        request: .init([
            "$model": ["inputs", "model"],
            "stream": true,
            "input": [[
                "role": "system",
                "content": [[
                    "type": "input_text",
                    "text": """
                        be an echo server.
                        before response, say 'hi [USER NAME]' first.
                        what I send to you, you send back.

                        the exceptions:
                        1. send "ping", back "pong"
                        2. send "ding", back "dang"
                    """
                ]]
            ], [
                "role": "system",
                "content": [[
                    "type": "input_text",
                    "#text": "you are talking to {{inputs.name}}"
                ]]
            ], [
                "role": "user",
                "content": [[
                    "type": "input_text",
                    "$text": ["inputs", "message"]
                ]]
            ]],
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


    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping"
        ]

        let states = try workflow.run0(inputs: inputs)
        for try await state in states {
            print("[*] \(state)")
            if case let .stream(stream) = state {
                for try await value in stream {
                    print("[*] \(value)")
                }
            }
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }

    try await client.shutdown()
}

@Test("testWorkflowRunWithConfig")
func testWorkflowRunWithConfig() async throws {
    let str = """
    nodes:
    - id: start_id
      type: START
      inputs:
        message: String
        name: String
        model: String

    - id: llm_id
      type: LLM
      modelName: test_openai
      request:
        $model:
          - inputs
          - model
        stream: true
        input:
            - role: system
              content:
                - type: input_text
                  text: "be an echo server.\nbefore response, say 'hi [USER NAME]' first.\nwhat I send to you, you send back.\n\nthe exceptions:\n1. send \\"ping\\", back \\"pong\\"\n2. send \\"ding\\", back \\"dang\\""
            - role: system
              content:
                - type: input_text
                  "#text": you are talking to {{inputs.name}}
            - role: user
              content:
                - type: input_text
                  $text:
                    - inputs
                    - message

    - id: end_id
      type: END

    edges:
    - from: start_id
      to: llm_id
    - from: llm_id
      to: end_id
    """

    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: str.data(using: .utf8)!)

    try Dotenv.make()

    let client = HTTPClient()

    let openai = LLMProvider(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", type: .OpenAI, models: [.init(name: "gpt-4o-mini", provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)!

    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping"
        ]

        let states = try workflow.run0(inputs: inputs)
        for try await state in states {
            print("[*] \(state)")
            if case let .stream(stream) = state {
                for try await value in stream {
                    print("[*] \(value)")
                }
            }
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }

    try await client.shutdown()
}
