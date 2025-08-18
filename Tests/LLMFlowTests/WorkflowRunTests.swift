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


@Test("testWorkflowRun")
func testWorkflowRun() async throws {
    let logger = Logger.testing
    
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
    let logger = Logger.testing
    
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
    let logger = Logger.testing
    
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
        temperature: 0.0
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

    let openai = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://gateway.ai.cloudflare.com/v1/3450ee851bc2d21db2c2c0de5656343e/openai/openrouter")

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(name: "test_openai", models: [.init(model: .init(name: "openai/gpt-4o-mini"), provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)!

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
}


@Test("testWorkflowRunWithConfigOpenRouterRepeat")
func testWorkflowRunWithConfigOpenRouterRepeat() async throws {
    let logger = Logger.testing
    
    let str = """
    nodes:
    - id: start_id
      type: START
      inputs:
        message: String
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
        instructions: |
            You are an experienced translator, and your task is accurately and vividly translating content or word into {{ workflow.inputs.langauge }}.
            These examples demonstrates the importance of paying attention to personal pronouns when translating sentences.
            <example>
            Translate the following content into {{ workflow.inputs.langauge }}.
            どうしたんだ、お雪！
            Translated {{ workflow.inputs.langauge }} text:
            怎么了，小雪！
            </example>
        temperature: 0.0
        topP: 1.0
        inputs:
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

    let openai = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://gateway.ai.cloudflare.com/v1/3450ee851bc2d21db2c2c0de5656343e/openai/openrouter")

    let solver = DummyLLMProviderSolver(
        "test_openai",
        .init(name: "test_openai", models: [.init(model: .init(name: "deepseek/deepseek-chat-v3-0324"), provider: openai)])
    )

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)!

    let inputs: [String: FlowData] = [
        "message": "どうしたんだ、お雪！",
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
}

/// Mock Server https://github.com/kevinzhow/mockai

@Test("testWorkflowProviderTimeout")
func testWorkflowProviderTimeout() async throws {
    // This test is used to test the timeout of the LLM provider.
    let logger = Logger.testing
    
    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://gateway.ai.cloudflare.com/v1/3450ee851bc2d21db2c2c0de5656343e/openai/openrouter")

    let openaiLocal = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "http://localhost:5002/v1")

    let client = AsyncHTTPClientTransport(configuration: .init(timeout: .seconds(4)))
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", models: [
            .init(model: .init(name: "gpt-4o-mini-timeout"), provider: openaiLocal),
                .init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let llmNode  = LLMNode(
        id: "llm_id",
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

@Test("testWorkflowProvider500Error")
func testWorkflowProvider500Error() async throws {
    // This test is used to test the timeout of the LLM provider.
    let logger = Logger.testing
    
    try Dotenv.make()

    let openai = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://gateway.ai.cloudflare.com/v1/3450ee851bc2d21db2c2c0de5656343e/openai/openrouter")

    let openaiLocal = LLMProviderConfiguration(type: .OpenAICompatible, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "http://localhost:5002/v1")

    let client = AsyncHTTPClientTransport(configuration: .init(timeout: .seconds(4)))
    let solver = DummyLLMProviderSolver(
        "gpt-4o-mini",
        .init(name: "gpt-4o-mini", models: [
            .init(model: .init(name: "gpt-4o-mini-error"), provider: openaiLocal),
                .init(model: .init(name: "gpt-4o-mini"), provider: openai)])
    )
    let startNode = StartNode(id: UUID().uuidString, name: nil, inputs: [:])

    let llmNode  = LLMNode(
        id: "llm_id",
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


@Test("testWorkflowRunWithConditionEdge")
func testWorkflowRunWithConditionEdge() async throws {
    let logger = Logger.testing
    
    let str = """
    nodes:
    - id: start_id
      type: START
      inputs:
        message: String
        name: String
        langauge: String
        model: String
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
              role: assistant
              '#content': "OK"
            - type: text
              role: user
              $content: 
                  - workflow
                  - inputs
                  - message
    
    - id: llm_special_id
      type: LLM
      modelName: test_openai
      request:
        stream: true
        instructions: "be an echo server.\nbefore response, say 'hi [USER NAME]' first.\nwhat I send to you, you send back.\n\nthe exceptions:\n1. send \\"ping\\", back \\"special pong\\"\n2. send \\"ding\\", back \\"special dang\\""
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
      to: llm_special_id
      condition:
        equal:
          variable: workflow.inputs.model
          value: special
    - from: template_id
      to: llm_id
    - from: llm_id
      to: end_id
    - from: llm_special_id
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
            "langauge": "zh-Hans",
            "model": "not_special"
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
        #expect(content?.contains("special") == false)
        
    } catch {
        Issue.record("Unexpected \(error)")
    }
    
    do {

        let inputs: [String: FlowData] = [
            "name": "John",
            "message": "ping",
            "langauge": "zh-Hans",
            "model": "special"
        ]

        let states = try workflow.run(inputs: inputs, context: .init())
        for try await state in states {
            logger.info("[*] State: \(state.node.type.rawValue) \(state.node.id) \(state.type) -> \(String(describing: state.value))")
        }
        
        let nodeResult = states.context[path: "llm_special_id", DataKeyPath.WorkflowNodeRunResultKey]
        let response = try AnyDecoder().decode(ModelResponse.self, from: nodeResult as AnySendable)
        let usage = response.usage
        let content = response.items.first?.message?.content?.first?.text?.content
        logger.info("[*] \(content ?? "nil")")
        logger.info("[*] \(String(describing: usage))")
        #expect(content?.contains("special") == true)
        
    } catch {
        Issue.record("Unexpected \(error)")
    }
}

