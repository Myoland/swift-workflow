//
//  testWorkflowRunWithConversation.swift
//  swift-workflow
//
//  Created by Huanan on 2025/9/8.
//

import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import GPT
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import Yams
import Logging

@testable import LLMFlow


@Test("testWorkflowRunWithConversation")
func testWorkflowRunWithConversation() async throws {
    let logger = Logger.testing

    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )
    let dummyConversationCache = DummyConversationCache()
    dummyConversationCache.update(conversationID: "fake_id", conversation: Conversation(items: [.input(.text(.init(role: .user, content: "I'm John")))]))
    
    
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let outputKey = "ultimate"
    let llmNode  = LLMNode(
        id: UUID().uuidString,
        name: nil,
        modelName: "gpt-4o-mini",
        output: outputKey,
        request: .init([
            "stream": false,
            "$conversationID": "workflow.inputs.conversation_id",
            "#instructions": """
                You are a translator, translate the following content into {{ workflow.inputs.lang }} directly without explanation.
                Before any tranlation, say hi [USER NAME] first.
            """,
            "inputs": [[
                "type": "text",
                "role": "user",
                "$content": "workflow.inputs.message",
            ]]
        ]))

    let endNode = EndNode(id: UUID().uuidString, name: nil)
    
    let locator = DummySimpleLocater(client, solver, dummyConversationCache)

    let workflow = Workflow(nodes: [
        startNode.id : startNode,
        llmNode.id : llmNode,
        endNode.id : endNode
    ], flows: [
        startNode.id : [.init(from: startNode.id, to: llmNode.id, condition: nil)],
        llmNode.id : [.init(from: llmNode.id, to: endNode.id, condition: nil)],
    ], startNodeID: startNode.id, locator: locator)


    let inputs: [String: FlowData] = [
        "lang": "ZH_CN",
        "message": "how's the weather today?",
        "conversation_id": "fake_id"
    ]

    let context = Context()
    
    let states = try workflow.run(inputs: inputs, context: context)
    for try await state in states {
        logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
    }

    
    let response = context["workflow.output.\(outputKey)"]
    print(response)
    
}
