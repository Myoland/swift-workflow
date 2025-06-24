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
    let yaml = try String(contentsOf: Bundle.module.url(forResource: "dify_fork", withExtension: "yaml")!)

    let decoder = YAMLDecoder()
    let config = try decoder.decode(Workflow.Config.self, from: yaml.data(using: .utf8)!)

    try Dotenv.make()

    let client = HTTPClient()

    let openai = LLMProvider(type: .OpenAI, name: "openai", apiKey: Dotenv["OPENAI_API_KEY"]!.stringValue, apiURL: "https://api.openai.com/v1")
    let openrouter = LLMProvider(type: .OpenAICompatible, name: "openrouter", apiKey: Dotenv["OPENROUTER_API_KEY"]!.stringValue, apiURL: "https://openrouter.ai/api/v1")


    let solver = DummyLLMProviderSolver([
        "gpt-4o-mini": .init(
            name: "gpt-4o-mini", type: .OpenAI, models: [.init(name: "gpt-4o-mini", provider: openai)]),
        "gemini-2.5-flash": .init(
            name: "gemini-2.5-flash", type: .OpenAICompatible, models: [.init(name: "google/gemini-2.5-flash-preview-05-20", provider: openrouter)])
    ])

    let locator = DummySimpleLocater(client, solver)
    let workflow = try Workflow(config: config, locator: locator)!

    do {

        let inputs: [String: FlowData] = [
            :
        ]

        let states = try workflow.run0(inputs: inputs)
        for try await state in states {
            print("[*] \(state)")
            if case let .stream(_, stream) = state {
                for try await value in stream {
                    print("[*] \(value)")
                }
            }
        }
    } catch {
        Issue.record("Unexpected \(error)")
    }

    try await client.shutdown()
}
