import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import GPT
import Logging

@testable import LLMFlow

@Test("testLLMNodeOpenAIRun")
func testLLMNodeOpenAIRun() async throws {
    let logger = Logger.testing
    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        "model_foo",
        .init(name: "model_foo", models: [.init(model: .init(name: "gpt-4o-mini") , provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)

    let context = Context()
    let executor = Executor(locator: locator, context: context)

    let node = LLMNode(id: "ID",
                       name: nil,
                       modelName: "model_foo",
                       output: nil,
                       request: .init([
                           "$instructions": """
                                be an echo server.
                                what I send to you, you send back.

                                the exceptions:
                                1. send "ping", back "pong"
                                2. send "ding", back "dang"
                           """,
                           "stream": true,
                           "inputs": [[
                               "type": "text",
                               "role": "user",
                               "content": "Ping",
                           ]]
                       ]))

    let output = try await node.run(executor: executor)

    guard let stream = output?.stream else {
        Issue.record("Shuld have a stream")
        return
    }

    for try await event in stream {
        let event = try AnyDecoder().decode(ModelStreamResponse.self, from: event)
        logger.info("[*] \(String(describing: event))")
    }
}
