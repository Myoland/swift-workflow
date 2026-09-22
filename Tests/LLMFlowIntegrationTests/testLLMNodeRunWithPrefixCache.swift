//
//  testLLMNodeRunWithPrefixCache.swift
//  swift-workflow
//
//  Created by Huanan on 2026/9/22.
//

import AsyncHTTPClient
import Foundation
import GPT
import LazyKit
import Logging
import OpenAPIAsyncHTTPClient
import SwiftDotenv
import SynchronizationKit
import Testing
import TestKit

@testable import LLMFlow

/// Keeps the stored prefix by its hash, so that runs without a conversation ID share it.
final class DummyPrefixCache: GPTConversationCache {
    private let references: LazyLockedValue<[String: Conversation.PrefixCacheReference]> = .init([:])

    var count: Int { references.withLock { $0.count } }

    func get(conversationID _: String?, prompt: Prompt) async throws -> Conversation? {
        guard let hash = prompt.prefixCacheHashValue else { return nil }
        return references.withLock { $0[hash] }.map { Conversation(prefixCacheReference: $0) }
    }

    func update(conversationID _: String?, conversation: Conversation?) async throws -> String? {
        guard let reference = conversation?.prefixCacheReference else { return nil }
        references.withLock { $0[reference.prefixHashValue] = reference }
        return reference.prefixHashValue
    }
}

/// Prefix caching requires at least 256 input tokens.
private let arkCacheContext = """
You are a literary analysis assistant. Use the reference below whenever you answer \
questions about the short story The Gift of the Magi by O. Henry.

Reference:
Della and Jim are a young married couple who live in a cheap furnished flat and have \
almost no spare money. Each of them owns exactly one thing they are proud of. Della has \
long, beautiful hair that falls below her knees. Jim has a gold pocket watch that \
belonged to his father and, before that, to his grandfather.
It is the day before Christmas and Della has managed to save only one dollar and \
eighty-seven cents to buy a present for Jim. After crying and then thinking it over, she \
goes to a hair goods shop and sells her hair for twenty dollars. She spends the money on \
a simple platinum chain for the watch, because Jim has been using an old leather strap \
and is shy about taking the watch out in company.
At home she curls what is left of her hair and waits, worried that Jim will no longer \
find her pretty. When Jim comes in he stares at her in a way she cannot read. He is not \
angry. He hands her a package that holds the set of tortoise shell combs she had wanted \
for a long time, which are useless now that her hair is gone. Della then gives him the \
chain, and Jim admits that he sold the watch to pay for the combs.
The narrator closes by comparing the two of them to the Magi, the wise men who brought \
gifts to the manger, and says that of all who give gifts, these two were the wisest.

Rules:
1. Keep every answer concise.
2. Do not invent events that are not in the reference.
"""

/// The node stores the prefix once, then every run references it by `previous_response_id`.
@Test("testLLMNodeRunWithPrefixCache")
func testLLMNodeRunWithPrefixCache() async throws {
    let logger = Logger.testing
    try Dotenv.make()

    let ark = LLMProviderConfiguration(
        type: .OpenAI, name: "ark", apiKey: Dotenv["ARK_API_KEY"]!.stringValue,
        apiURL: "https://ark.ap-southeast.bytepluses.com/api/v3"
    )

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        "model_foo",
        .init(name: "model_foo", models: [.init(model: .init(name: "seed-2-0-mini-260428"), provider: ark)])
    )
    let cache = DummyPrefixCache()
    let locator = DummySimpleLocater(client, solver, cache)

    let node = LLMNode(
        id: "ID",
        name: nil,
        modelName: "model_foo",
        timeout: 30,
        output: nil,
        context: nil,
        request: .init([
            "stream": false,
            "store": true, // required by the explicit cache of ModelArk.
            "extraBody": ["thinking": ["type": "disabled"]],
            "context": ["cachingPrefixLength": 1],
            "inputs": [[
                "type": "text",
                "role": "system",
                "content": .init(stringLiteral: arkCacheContext),
            ], [
                "type": "text",
                "role": "user",
                "$content": "inputs.question",
            ]],
        ])
    )

    let questions = [
        "Why does Della sell her hair? One sentence.",
        "What does Jim sell, and why? One sentence.",
    ]

    var cached: [Int] = []
    for question in questions {
        let context = Context()
        context[path: ["inputs", "question"]] = question

        let executor = Executor(locator: locator, context: context)
        let output = try await node.run(executor: executor)

        let response = try AnyDecoder().decode(ModelResponse.self, from: try #require(output?.value))
        logger.info("[*] usage: \(String(describing: response.usage)) text: \(response.items.first?.message?.content?.first?.text?.content ?? "nil")")
        cached.append(response.usage?.cached ?? 0)
    }

    // The prefix is stored once, and hit by every run.
    #expect(cache.count == 1)
    #expect(cached.allSatisfy { $0 > 0 })
}
