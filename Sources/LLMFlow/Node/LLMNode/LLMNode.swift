//
//  Node+LLM.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//
//
//

import Foundation
import HTTPTypes
import LazyKit
import AsyncAlgorithms
import OSLog
import OpenAPIRuntime


public enum LLMProviderType: String, Hashable, Codable, Sendable {
    case OpenAI
    case OpenAICompatible
    case Gemini
}

public struct LLMProvider: Hashable, Codable, Sendable {
    public let type: LLMProviderType

    public let name: String
    public let apiKey: String
    public let apiURL: String

    public init(type: LLMProviderType, name: String, apiKey: String, apiURL: String) {
        self.type = type
        self.name = name
        self.apiKey = apiKey
        self.apiURL = apiURL
    }
}


public struct LLMQualifiedModel: Hashable, Codable, Sendable {
    public let name: String
    public let provider: LLMProvider

    public init(name: String, provider: LLMProvider) {
        self.name = name
        self.provider = provider
    }
}

public struct LLMModel: Sendable {
    public let name: String

    public let type: LLMProviderType
    public let models: [LLMQualifiedModel]

    public init(name: String, type: LLMProviderType, models: [LLMQualifiedModel]) {
        self.name = name
        self.models = models
        self.type = type
    }
}

public protocol LLMProviderSolver {
    func resolve(modelName: String) -> LLMModel?
}


struct LLMNode: Node {
    let id: ID
    let name: String?
    let type: NodeType

    let modelName: String
    let request: ModelDecl

    init(
        id: ID,
        name: String?,
        modelName: String,
        request: ModelDecl
    ) {
        self.id = id
        self.name = name
        self.type = .LLM
        self.modelName = modelName
        self.request = request
    }
}

extension LLMNode {

    public func run(executor: Executor) async throws {
        guard let locator = executor.locator,
              let client = locator.resolve(shared: ClientTransport.self),
            let llmSolver = locator.resolve(shared: LLMProviderSolver.self),
            let llm = llmSolver.resolve(modelName: modelName)
        else {
            executor.logger.error("[*] LLMModel Not Matched For '\(modelName)'")
            todo("Throw error for miss LLMModel")
        }

        let context = executor.context
        let inputs = context.filter(keys: nil)

        // context.output.withLock { $0 = output }
    }
}

extension LLMNode {
    public func wait(_ context: Context) async throws -> Context.Value? {
        let output = context.output.withLock { $0 }
        if case .none = output {
            return nil
        }

        if case let .block(value) = output {
            return value
        }

        guard case .stream(let stream) = output else {
            return nil
        }

        return try await Array(stream)
    }

    func update(_ context: Context, value: any Context.Value) throws {
        try updateIntoResult(context, value: value)
    }
}
