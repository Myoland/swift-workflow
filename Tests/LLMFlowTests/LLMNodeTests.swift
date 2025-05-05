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
    context.update(key: "input", value: "ping")

    let node = LLMNode(id: "ID",
                       name: nil,
                       modelName: "openai",
                       request: [
                           "input": "input",
                           "model": "model"
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
            print(event.event)
        }
    } catch {

    }

    try await client.shutdown()
}
