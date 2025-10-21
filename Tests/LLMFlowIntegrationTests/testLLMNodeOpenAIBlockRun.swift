import AsyncHTTPClient
import Foundation
import GPT
import LazyKit
import Logging
import OpenAPIAsyncHTTPClient
import SwiftDotenv
import Testing
import TestKit

@testable import LLMFlow

@Test("testLLMNodeOpenAIBlockRun")
func testLLMNodeOpenAIBlockRun() async throws {
    let logger = Logger.testing
    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        "model_foo",
        .init(name: "model_foo", models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)

    let context = Context()
    let executor = Executor(locator: locator, context: context)

    let node = LLMNode(id: "ID",
                       name: nil,
                       modelName: "model_foo",
                       output: nil,
                       context: nil,
                       request: .init([
                           "#instructions": """
                                be an echo server.
                                what I send to you, you send back.

                                the exceptions:
                                1. send "ping", back "pong"
                                2. send "ding", back "dang"
                           """,
                           "stream": false,
                           "inputs": [[
                               "type": "text",
                               "role": "user",
                               "content": "Ping",
                           ]],
                       ]))
    let output = try await node.run(executor: executor)

    guard let value = output?.value else {
        Issue.record("Shuld have a stream")
        return
    }

    let response = try AnyDecoder().decode(ModelResponse.self, from: value as Any)
    logger.info("[*] \(String(describing: response))")
}
