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

@Test("testWorkflowRunWithYaml")
func testWorkflowRunWithYaml() async throws {
    let logger = Logger.testing

    guard let url = Bundle.module.url(forResource: "testWorkflowRunWithYaml", withExtension: "yaml") else {
        Issue.record("yaml file read failed")
        return
    }
    let data = try Data(contentsOf: url)

    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: data)

    try Dotenv.make()

    let client = AsyncHTTPClientTransport()

    let openai = LLMProviderConfiguration(
        type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue,
        apiURL: "https://api.openai.com/v1"
    )

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(
            name: "test_openai",
            models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)]
        )
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)

    let inputs: [String: FlowData] = [
        "name": "John",
        "message": "ping",
        "langauge": "zh-Hans",
    ]

    let states = try workflow.run(inputs: inputs, context: .init())
    for try await state in states {
        logger.info(
            "[*] State: \(state.node.type.rawValue) \(state.node.id) \(state.type) -> \(String(describing: state.value))"
        )
    }

    let nodeResult = states.context[path: "llm_id", ContextStoreKey.WorkflowNodeRunOutputKey]
    let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
    let usage = response.usage
    let content = response.items.first?.message?.content?.first?.text?.content
    logger.info("[*] \(content ?? "nil")")
    logger.info("[*] \(String(describing: usage))")
}
