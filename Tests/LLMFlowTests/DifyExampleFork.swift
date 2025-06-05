//
//  DifyExampleFork.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/3.
//

import AsyncHTTPClient
import LazyKit
import Foundation
import SwiftDotenv
import Testing
import TestKit
import Yams

@testable import LLMFlow

@Test("testDifyExampleFork")
func testDifyExampleFork() async throws {
    let yaml = """
    """
    
    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: yaml.data(using: .utf8)!)
    
    let workflow = try Workflow.buildWorkflow(config: config)
    
    try Dotenv.make()
    
    let client = HTTPClient()
    
    let solver = DummyLLMProviderSolver([
        "openai": .OpenAI(.init(apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")),
        "google": .OpenAICompatible(.init(apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://openrouter.ai/api/v1"))
    ])
    
    
    var context = Context(locater: DummySimpleLocater(client, solver))
    
    do {
        
        let inputs: [String: FlowData] = [:]
        
        let output = try await workflow.run(context: &context, pipe: .block(inputs))
        
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
