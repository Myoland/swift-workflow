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
    #expect(response.debugDescription.contains("John") == true)
}

@Test("testWorkflowRunWithConversationYAML")
func testWorkflowRunWithConversationYAML() async throws {
    let logger = Logger.testing

    let str = """
        nodes:
        - id: start_id
          type: START
          inputs:
            lang: String
            message: String
            conversation_id: String

        - id: llm_id
          type: LLM
          modelName: test_openai
          request:
            stream: false
            "$conversationID": "workflow.inputs.conversation_id"
            "#instructions": |
                You are a translator, translate the following content into {{ workflow.inputs.lang }} directly without explanation.
                Before any tranlation, say hi [USER NAME] first.
            inputs:
                - type: text
                  role: user
                  '#content': "{{ workflow.inputs.message }}"

        - id: end_id
          type: END

        edges:
        - from: start_id
          to: llm_id
        - from: llm_id
          to: end_id
        """

    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: str.data(using: .utf8)!)

    try Dotenv.make()

    let client = AsyncHTTPClientTransport()

    let openai = LLMProviderConfiguration(
        type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue,
        apiURL: "https://api.openai.com/v1")

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(
            name: "test_openai",
            models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )
    
    let dummyConversationCache = DummyConversationCache()
    dummyConversationCache.update(conversationID: "fake_id", conversation: Conversation(items: [
        .input(.text(.init(role: .user, content: "I'm John")))
    ]))
    
    let locator = DummySimpleLocater(client, solver, dummyConversationCache)
    let workflow = try Workflow(config: config, locator: locator)

    let inputs: [String: FlowData] = [
        "lang": "ZH_CN",
        "message": "how's the weather today?",
        "conversation_id": "fake_id"
    ]

    let states = try workflow.run(inputs: inputs, context: .init())
    for try await state in states {
        logger.info(
            "[*] State: \(state.node.type.rawValue) \(state.node.id) \(state.type) -> \(String(describing: state.value))"
        )
    }

    let nodeResult = states.context[
        path: "llm_id", ContextStoreKey.WorkflowNodeRunOutputKey]
    let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
    let content = response.items.first?.message?.content?.first?.text?.content
    #expect(content?.contains("John") == true)
}
