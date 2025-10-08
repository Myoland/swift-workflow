import GPT
import LazyKit
import Logging
import OpenAPIAsyncHTTPClient
import SwiftDotenv
import SynchronizationKit
import Testing

@testable import LLMFlow

final class DummyConversationCache: GPTConversationCache {
    private let conversations: LazyLockedValue<[String: Conversation]> = .init([:])

    func get(conversationID: String?, context: LLMFlow.Context.Store) async throws -> Conversation? {
        guard let conversationID else { return nil }
        return conversations.withLock { $0[conversationID] }
    }

    func update(conversationID: String?, context: LLMFlow.Context.Store, conversation: Conversation?) async throws -> String? {
        guard let conversationID else { return nil }
        conversations.withLock { $0[conversationID] = conversation }
        return conversationID
    }
}

@Test("testLLMNodeRunWithGPTSession")
func testLLMNodeRunWithGPTSession() async throws {
    let logger = Logger.testing
    try Dotenv.make()

    let openai = LLMProviderConfiguration(
        type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue,
        apiURL: "https://api.openai.com/v1")

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        .init(name: "model_foo", models: [
            .init(model: .init(name: "gpt-4o-mini"), provider: openai)
        ])
    )
    let dummyConversationCache = DummyConversationCache()
    let locator = DummySimpleLocater(client, solver, dummyConversationCache)

    let context = Context()

    let node = LLMNode(
        id: "ID",
        name: nil,
        modelName: "model_foo",
        output: nil,
        context: nil,
        request: .init([
            "$conversationID": "inputs.conversation_id",
            "stream": true,
            "inputs": [
                [
                    "type": "text",
                    "role": "user",
                    "$content": "inputs.msg",
                ]
            ],
        ]))

    context[path: ["inputs", "conversation_id"]] = "fake_id"
    context[path: ["inputs", "msg"]] = "Hello, I'm John"
    do {
        let executor = Executor(locator: locator, context: context)
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


    context[path: ["inputs", "msg"]] = "What is my name?"
    do {
        let executor = Executor(locator: locator, context: context)
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
}
