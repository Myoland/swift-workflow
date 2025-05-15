import AsyncHTTPClient
import Foundation
import SwiftDotenv
import Testing
import TestHelper

@testable import LLMFlow

final class DummySimpleLocater: StoreLocator {
    typealias Store = Any & Sendable

    let stores: [Store]

    init(_ stores: Store...) {
        self.stores = stores
    }

    func resolve<T>(shared _: T.Type) -> T? {
        (stores.first { $0 is T }) as? T
    }

    func resolve<K, T>(for _: K.Type, as _: T.Type) -> T? {
        (stores.first { $0 is T }) as? T
    }
}

struct DummyLLMProviderSolver: LLMProviderSolver {
    let store: [String: LLMProvider]

    init(_ store: [String: LLMProvider]) {
        self.store = store
    }

    init(_ name: String, _ provider: LLMProvider) {
        store = [name: provider]
    }

    func resolve(modelName: String) -> LLMProvider? {
        store[modelName]
    }
}

@Test("testLLMNodeRun")
func testLLMNodeRun() async throws {

    try Dotenv.make()

    let client = HTTPClient()
    let solver = DummyLLMProviderSolver(
        "dify",
        .Dify(.init(apiKey: Dotenv["DIFY_API_KEY"]!.stringValue, apiURL: "https://api.dify.ai/v1")))
    var context = Context(locater: DummySimpleLocater(client, solver))
    context.update(key: "user_id", value: "Fake")
    context.update(key: "query", value: "ping")

    let node = LLMNode(id: "ID",
                       name: nil,
                       modelName: "dify",
                       request: [
                            "user": "user_id",
                            "query": "query"
                       ],
                       response: "")
    do {
        let pipe = try await node.run(context: &context)
        guard case let .stream(stream) = pipe else {
            Issue.record("Shuld have a stream")
            try await client.shutdown()
            return
        }

        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))

        for try await event in interpreter {
            print(event)
        }

    } catch {

    }

    try await client.shutdown()
}

@Test("testLLMNodeOpenAiRun")
func testLLMNodeOpenAiRun() async throws {

    try Dotenv.make()

    let client = HTTPClient()
    let solver = DummyLLMProviderSolver(
        "openai",
        .OpenAI(.init(apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1"))
    )
    var context = Context(locater: DummySimpleLocater(client, solver))
    context.update(key: "model", value: "gpt-4o-mini")
    context.update(key: "stream", value: true)
    context.update(key: "input", value: [
        [
            "role": "system",
            "content": [
                [
                    "type": "input_text",
                    "text": """
                        be an echo server.
                        what I send to you, you send back.

                        the exceptions:
                        1. send "ping", back "pong"
                        2. send "ding", back "dang"
                    """
                ]
            ]
        ],
        [
            "role": "user",
            "content": [
                [
                    "type": "input_text",
                    "text": "ping"
                ]
            ]
        ]
    ])

    let node = LLMNode(id: "ID",
                       name: nil,
                       modelName: "openai",
                       request: [
                           "input": "input",
                           "model": "model",
                           "stream": "stream"
                       ],
                       response: "")
    do {
        let pipe = try await node.run(context: &context)
        guard case let .stream(stream) = pipe else {
            Issue.record("Shuld have a stream")
            try await client.shutdown()
            return
        }
        
        let decoder = JSONDecoder()
//        decoder.dateDecodingStrategy = .secondsSince1970

        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))

        for try await event in interpreter {
            print("[*]", event)
            if let data = event.data.data(using: .utf8) {
                let reponse = try decoder.decode(OpenAIModelStreamResponse.self, from: data)
                print(reponse)
            }
            
            
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }

    try await client.shutdown()
}
