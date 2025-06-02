import AsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import Yams

@testable import LLMFlow


@Test("testWorkflowRun")
func testWorkflowRun() async throws {
    
    try Dotenv.make()

    let client = HTTPClient()
    
    let solver = DummyLLMProviderSolver(
        "test_openai",
        .OpenAI(.init(apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com"))
    )

    let startNode = StartNode(id: UUID().uuidString, name: nil, input: [:])

    let llmNode  = LLMNode(
        id: UUID().uuidString,
        name: nil,
        modelName: "test_openai",
        request: .init([
            "$model": ["inputs", "model"],
            "stream": true,
            "input": [[
                "role": "system",
                "content": [[
                    "type": "input_text",
                    "text": """
                        be an echo server.
                        before response, say 'hi [USER NAME]' first.
                        what I send to you, you send back.
                    
                        the exceptions:
                        1. send "ping", back "pong"
                        2. send "ding", back "dang"
                    """
                ]]
            ], [
                "role": "system",
                "content": [[
                    "type": "input_text",
                    "#  ": "you are talking to {{inputs.name}}"
                ]]
            ], [
                "role": "user",
                "content": [[
                    "type": "input_text",
                    "$text": ["inputs", "message"]
                ]]
            ]],
        ]))

    let endNode = EndNode(id: UUID().uuidString, name: nil)

    var context = Context(locater: DummySimpleLocater(client, solver))

    let workflow = Workflow(nodes: [
        startNode.id : startNode,
        llmNode.id : llmNode,
        endNode.id : endNode
    ], flows: [
        startNode.id : [.init(from: startNode.id, to: llmNode.id, condition: nil)],
        llmNode.id : [.init(from: llmNode.id, to: endNode.id, condition: nil)],
    ], startNodeID: startNode.id)
    
    do {
        
        let inputs: [String: FlowData] = [
            "name": "John",
            "model": "gpt-4o-mini",
            "message": "ping"
        ]
        
        let output = try await workflow.run(context: &context, pipe: .block(inputs))
        
        guard case let .stream(stream) = output else {
            Issue.record("Shuld have a stream")
            try await client.shutdown()
            return
        }
        
        let decoder = JSONDecoder()
        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))
        
        for try await event in interpreter {
            if let data = event.data.data(using: .utf8) {
                let response = try decoder.decode(OpenAIModelStreamResponse.self, from: data)
                print(response)
            }
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }
    
    try await client.shutdown()
}

@Test("testWorkflowRunWithConfig")
func testWorkflowRunWithConfig() async throws {
    let str = """
    nodes: 
    - id: start_id
      type: START
      input:
        message: String
        name: String
        model: String
      
    - id: llm_id
      type: LLM
      modelName: test_openai
      request: 
        $model: 
          - inputs 
          - model
        stream: true
        input:
            - role: system
              content:
                - type: input_text
                  text: "be an echo server.\nbefore response, say 'hi [USER NAME]' first.\nwhat I send to you, you send back.\n\nthe exceptions:\n1. send \\"ping\\", back \\"pong\\"\n2. send \\"ding\\", back \\"dang\\""
            - role: system
              content:
                - type: input_text
                  "#text": you are talking to {{inputs.name}}
            - role: user
              content:
                - type: input_text
                  $text: 
                    - inputs 
                    - message
    
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
    
    let workflow = try Workflow.buildWorkflow(config: config)
    
    try Dotenv.make()
    
    let client = HTTPClient()
    
    let solver = DummyLLMProviderSolver(
        "test_openai",
        .OpenAI(.init(apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com"))
    )
    
    var context = Context(locater: DummySimpleLocater(client, solver))
    
    do {
        
        let inputs: [String: FlowData] = [
            "name": "John",
            "model": "gpt-4o-mini",
            "message": "ping"
        ]
        
        let output = try await workflow.run(context: &context, pipe: .block(inputs))
        
        guard case let .stream(stream) = output else {
            Issue.record("Shuld have a stream")
            try await client.shutdown()
            return
        }
        
        let decoder = JSONDecoder()
        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))
        
        for try await event in interpreter {
            if let data = event.data.data(using: .utf8) {
                let response = try decoder.decode(OpenAIModelStreamResponse.self, from: data)
                print(response)
            }
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }
    
    try await client.shutdown()
}
