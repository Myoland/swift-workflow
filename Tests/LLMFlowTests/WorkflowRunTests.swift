import AsyncHTTPClient
import OpenAPIAsyncHTTPClient
import GPT
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import Yams
import os.log

@testable import LLMFlow


@Test("testWorkflowRun")
func testWorkflowRun() async throws {
    let logger = Logger(subsystem: "me.afuture.workflow.node.llm", category: "debug")
    
    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let client = AsyncHTTPClientTransport()
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let llmNode  = LLMNode(
        id: UUID().uuidString,
        name: nil,
        modelName: "gpt-4o-mini",
        request: .init([
            "stream": true,
            "instructions": """
                be an echo server.
                before response, say 'hi [USER NAME]' first.
                what I send to you, you send back.

                the exceptions:
                1. send "ping", back "pong"
                2. send "ding", back "dang"
            """,
            "inputs": [[
                "type": "text",
                "role": "system",
                "#content": "you are talking to {{workflow.inputs.name}}"
            ], [
                "type": "text",
                "role": "user",
                "$content": ["workflow", "inputs", "message"],
            ]]
        ]))

    let endNode = EndNode(id: UUID().uuidString, name: nil)
    let locator = DummySimpleLocater(client, solver)

    let workflow = Workflow(nodes: [
        startNode.id : startNode,
        llmNode.id : llmNode,
        endNode.id : endNode
    ], flows: [
        startNode.id : [.init(from: startNode.id, to: llmNode.id, condition: nil)],
        llmNode.id : [.init(from: llmNode.id, to: endNode.id, condition: nil)],
    ], startNodeID: startNode.id, locator: locator)


    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping"
        ]
        
        let context = Context()
        let states = try workflow.run(inputs: inputs, context: context)
        for try await state in states {
            logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }
}

@Test("testWorkflowRunWithConfig")
func testWorkflowRunWithConfig() async throws {
    let logger = Logger(subsystem: "me.afuture.workflow.node.llm", category: "debug")
    
    let str = """
    nodes:
    - id: start_id
      type: START
      inputs:
        message: String
        name: String
        langauge: String
    
    - id: template_id
      type: TEMPLATE
      template: >
        {% if workflow.inputs.langauge == "zh-Hans" %}简体中文{% elif workflow.inputs.langauge == "zh-Hant" or workflow.inputs.langauge == "zh" %}繁體中文{% elif  workflow.inputs.langauge == "ja"%}日本語{% elif  workflow.inputs.langauge == "vi"%}Tiếng Việt{% elif  workflow.inputs.langauge == "ko"%}한국어{% else %}English{% endif %}

    - id: llm_id
      type: LLM
      modelName: test_openai
      request:
        stream: true
        instructions: "be an echo server.\nbefore response, say 'hi [USER NAME]' first.\nwhat I send to you, you send back.\n\nthe exceptions:\n1. send \\"ping\\", back \\"pong\\"\n2. send \\"ding\\", back \\"dang\\""
        inputs:
            - type: text
              role: user
              '#content': "you are talking to {{workflow.inputs.name}} in {{ template_id.result }}"
            - type: text
              role: user
              $content: 
                  - workflow
                  - inputs
                  - message

    - id: end_id
      type: END

    edges:
    - from: start_id
      to: template_id
    - from: template_id
      to: llm_id
    - from: llm_id
      to: end_id
    """

    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: str.data(using: .utf8)!)

    try Dotenv.make()

    let client = AsyncHTTPClientTransport()

    let openai = LLMProviderConfiguration(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(name: "test_openai", models: [.init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)!

    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping",
            "langauge": "zh-Hans"
        ]

        let states = try workflow.run(inputs: inputs, context: .init())
        for try await state in states {
            logger.info("[*] State: \(state.node.type.rawValue) \(state.node.id) \(state.type) -> \(String(describing: state.value))")
        }
        
        let nodeResult = states.context[path: "llm_id", DataKeyPath.WorkflowNodeRunResultKey]
        let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
        let usage = response.usage
        let content = response.items.first?.message?.content?.first?.text?.content
        logger.info("[*] \(content ?? "nil")")
        logger.info("[*] \(String(describing: usage))")
        
    } catch {
        Issue.record("Unexpected \(error)")
    }
}


@Test("testWorkflowRunWithConfigOpenRouter")
func testWorkflowRunWithConfigOpenRouter() async throws {
    let logger = Logger(subsystem: "me.afuture.workflow.node.llm", category: "debug")
    
    let str = """
    nodes:
    - id: start_id
      type: START
      inputs:
        message: String
        name: String
        langauge: String
    
    - id: template_id
      type: TEMPLATE
      template: >
        {% if workflow.inputs.langauge == "zh-Hans" %}简体中文{% elif workflow.inputs.langauge == "zh-Hant" or workflow.inputs.langauge == "zh" %}繁體中文{% elif  workflow.inputs.langauge == "ja"%}日本語{% elif  workflow.inputs.langauge == "vi"%}Tiếng Việt{% elif  workflow.inputs.langauge == "ko"%}한국어{% else %}English{% endif %}

    - id: llm_id
      type: LLM
      modelName: test_openai
      request:
        stream: true
        instructions: "be an echo server.\nbefore response, say 'hi [USER NAME]' first.\nwhat I send to you, you send back.\n\nthe exceptions:\n1. send \\"ping\\", back \\"pong\\"\n2. send \\"ding\\", back \\"dang\\""
        tempture: 0.0
        topP: 1.0
        inputs:
            - type: text
              role: user
              '#content': "you are talking to {{workflow.inputs.name}} in {{ template_id.result }}"
            - type: text
              role: assistant
              '#content': "OK"
            - type: text
              role: user
              $content: 
                  - workflow
                  - inputs
                  - message

    - id: end_id
      type: END

    edges:
    - from: start_id
      to: template_id
    - from: template_id
      to: llm_id
    - from: llm_id
      to: end_id
    """

    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: str.data(using: .utf8)!)

    try Dotenv.make()

    let client = AsyncHTTPClientTransport()

    let openai = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://openrouter.ai/api/v1")

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(name: "test_openai", models: [.init(model: .init(name: "openai/gpt-4o-mini"), provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)!

    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping",
            "langauge": "zh-Hans"
        ]

        let states = try workflow.run(inputs: inputs, context: .init())
        for try await state in states {
            logger.info("[*] State: \(state.type) -> \(String(describing: state.value))")
        }
        
        let nodeResult = states.context[path: "llm_id", DataKeyPath.WorkflowNodeRunResultKey]
        let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
        let usage = response.usage
        let content = response.items.first?.message?.content?.first?.text?.content
        logger.info("[*] \(content ?? "nil")")
        logger.info("[*] \(String(describing: usage))")
        
    } catch {
        Issue.record("Unexpected \(error)")
    }
}
