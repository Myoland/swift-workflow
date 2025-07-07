import AsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit

@testable import LLMFlow

final class DummySimpleLocater: ServiceLocator {
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
        .init(name: "model_foo", type: .OpenAI, models: [.init(name: "gpt-4o-mini", provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)

    let context = Context()
    let executor = Executor(locator: locator, context: context)

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
        try await node.run(executor: executor)
        let output = executor.context.output.withLock { $0 }

         guard case let .stream(stream) = output else {
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
        .init(name: "model_foo", type: .OpenAICompatible, models: [.init(name: "gpt-4o-mini", provider: openaiCompatiable)])
    )
    let locater = DummySimpleLocater(client, solver)

    let executor = Executor(locator: locater)

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
        try await node.run(executor: executor)
        let output = executor.context.output.withLock { $0 }

        guard case let .stream(stream) = output else {
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


@Test("testXXXX")
func testXXXX() async throws {
    try Dotenv.make()
    
    let client = HTTPClient()

    let openai = OpenAICompatibleClient(httpClient: client, configuration: .init(apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v0"))
    
    let response = try await openai.send(request: .init(
            messages: [
                .system(.init(role: .system, content: .text("""
                        be an echo server.
                        what I send to you, you send back.

                        the exceptions:
                        1. send "ping", back "pong"
                        2. send "ding", back "dang"
                    """), name: nil)),
                .user(.init(role: .user, content: .text("ping"), name: nil))
            ],
            model: "gpt-4o-mini",
            audio: nil,
            frequencyPenalty: nil,
            logitBias: nil,
            logprobs: nil,
            maxCompletionTokens: nil,
            metadata: nil,
            modalities: nil,
            n: nil,
            parallelToolCalls: nil,
            prediction: nil,
            presencePenalty: nil,
            reasoningEffort: nil,
            responseFormat: nil,
            seed: nil,
            serviceTier: nil,
            stop: nil,
            store: nil,
            stream: true,
            streamOptions: nil,
            temperature: nil,
            toolChoice: nil,
            tools: nil,
            topLogprobs: nil,
            topP: nil,
            user: nil,
            webSearchOptions: nil
        ))
    
    let body = response.body.buffer(policy: .unbounded).cached()
    for try await chunk in body {
        let str = String(buffer: chunk)
        print(str)
    }
    
    for try await chunk in body {
        let str = String(buffer: chunk)
        print(str)
    }
    
    
    try await client.shutdown()
}
