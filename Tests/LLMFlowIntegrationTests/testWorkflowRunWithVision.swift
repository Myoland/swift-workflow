//
//  testWorkflowRunWithVision.swift
//  swift-workflow
//
//  Created by kevinzhow on 2025/11/03.
//

import AsyncHTTPClient
import Foundation
import GPT
import LazyKit
import Logging
import OpenAPIAsyncHTTPClient
import SwiftDotenv
import Testing
import TestKit
import Yams

@testable import LLMFlow

@Test("testWorkflowRunWithVision")
func testWorkflowRunWithVision() async throws {
    let logger = Logger.testing

    let str = """
    nodes:
    - id: start_id
      type: START
      inputs:
        url: String
    - id: llm_id
      type: LLM
      modelName: test_openai
      request:
        stream: false
        instructions: You are helpful assistant.
        temperature: 0.0
        topP: 1.0
        inputs:
            - type: image
              role: user
              '$url': "workflow.inputs.url"
            - type: text
              role: user
              content: "Describe this image"

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

    let client = AsyncHTTPClientTransport()

    let openai = LLMProviderConfiguration(
        type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue,
        apiURL:
        "https://gateway.ai.cloudflare.com/v1/3450ee851bc2d21db2c2c0de5656343e/openai/openrouter"
    )

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(
            name: "test_openai",
            models: [.init(model: .init(name: "qwen/qwen3-vl-30b-a3b-instruct"), provider: openai)]
        )
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)

    let inputs: [String: FlowData] = [
        "url": "https://static.miraa.app/photo_2025-10-29%2015.00.26.jpeg",
    ]

    let states = try workflow.run(inputs: inputs, context: .init())
    for try await state in states {
        logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
    }

    let nodeResult = states.context[path: "llm_id", ContextStoreKey.WorkflowNodeRunOutputKey]
    let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
    let usage = response.usage
    let content = response.items.first?.message?.content?.first?.text?.content
    logger.info("[*] \(content ?? "nil")")
    logger.info("[*] \(String(describing: usage))")
}
