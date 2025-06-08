import AsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit

@testable import LLMFlow

final class DummySimpleLocater: StoreLocator {
    typealias Store = AnySendable

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
    let store: [String: LLMModel]

    init(_ store: [String: LLMModel]) {
        self.store = store
    }

    init(_ name: String, _ provider: LLMModel) {
        store = [name: provider]
    }

    func resolve(modelName: String) -> LLMModel? {
        store[modelName]
    }
}


@Test("testLLMNodeOpenAIRun")
func testLLMNodeOpenAIRun() async throws {

    try Dotenv.make()

    let openai = LLMProvider(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")
    
    let client = HTTPClient()
    let solver = DummyLLMProviderSolver(
        "model_foo",
        .init(name: "model_foo", models: [.init(name: "gpt-4o-mini", provider: openai)])
    )
    var context = Context(locater: DummySimpleLocater(client, solver))

    let node = LLMNode(id: "ID",
                       name: nil,
                       modelName: "model_foo",
                       request: .init([
                           "$model": [
                               "inputs",
                               "model"
                           ],
                           "stream": true,
                           "input": [[
                               "role": "system",
                               "content": [[
                                    "type": "input_text",
                                    "text": """
                                        be an echo server.
                                        what I send to you, you send back.
                                    
                                        the exceptions:
                                        1. send "ping", back "pong"
                                        2. send "ding", back "dang"
                                    """
                               ]]
                           ],[
                               "role": "user",
                               "content": [[
                                    "type": "input_text",
                                    "text": "ping"
                               ]]
                           ]],
                       ]))
    do {
        let pipe = try await node.run(context: context, pipe: .none)
        guard case let .stream(stream) = pipe else {
            Issue.record("Shuld have a stream")
            try await client.shutdown()
            return
        }

        for try await event in stream {
            print("[*] \(event)")
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }

    try await client.shutdown()
}

@Test("testLLMNodeOpenAICompatibleRun")
func testLLMNodeOpenAICompatibleRun() async throws {
    
    try Dotenv.make()
    
    let openaiCompatiable = LLMProvider(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")
    
    let client = HTTPClient()
    let solver = DummyLLMProviderSolver(
        "model_foo",
        .init(name: "model_foo", models: [.init(name: "gpt-4o-mini", provider: openaiCompatiable)])
    )
    let context = Context(locater: DummySimpleLocater(client, solver))
    
    let node = LLMNode(
        id: "ID",
        name: nil,
        modelName: "model_foo",
        request: .init([
            "$model": [
                "inputs",
                "model"
            ],
            "stream": true,
            "messages": [
                [
                    "role": "system",
                    "content": """
                        be an echo server.
                        what I send to you, you send back.
                    
                        the exceptions:
                        1. send "ping", back "pong"
                        2. send "ding", back "dang"
                    """
                ],
                [
                    "role": "user",
                    "content": "ping"
                ]
            ],
        ]))
    do {
        let pipe = try await node.run(context: context, pipe: .none)
        
        guard case let .stream(stream) = pipe else {
            Issue.record("Shuld have a stream")
            try await client.shutdown()
            return
        }
        
        for try await event in stream {
            print("[*] \(event)")
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }
    
    try await client.shutdown()
}
