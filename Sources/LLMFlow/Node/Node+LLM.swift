//
//  Node+LLM.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//
//
//

import AsyncAlgorithms
import Foundation
import GPT
import HTTPTypes
import LazyKit
import OSLog
import OpenAPIRuntime

public protocol LLMProviderSolver {
    func resolve(modelName: String) -> LLMQualifiedModel?
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
        guard let locator = executor.locator else {
            todo("Throw error for LLMModel not found locator")
        }

        guard let client = locator.resolve(shared: ClientTransport.self) else {
            todo("Throw error for LLMModel not found client")
        }

        guard
            let llmSolver = locator.resolve(shared: LLMProviderSolver.self),
            let llm = llmSolver.resolve(modelName: modelName)
        else {
            todo("Throw error for miss LLMModel name '\(modelName)'")
        }

        let context = executor.context

        let inputs = context.filter(keys: nil) // TODO: only get necessary values
        let renderedValues = try request.render(inputs)
        let prompt: Prompt = try AnyDecoder().decode(from: renderedValues)
        executor.logger.info("[*] LLMNode(\(id)) Prompt: \(String(describing: prompt))")

        let session = GPTSession(client: client)

        for model in llm.models {
            let stream = try await session.send(prompt, model: model)
            let output = stream.map { response in
                return try AnyEncoder().encode(response)
            }.cached().eraseToAnyAsyncSequence()
            context.output.withLock { $0 = .stream(output) }
            return  // TODO: retry
        }
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

        let response = try await stream.first { value in
            let response = value as? [String: AnySendable]
            let event = response?["event"] as? String
            return event == ModelStreamResponse.EventName.completed.rawValue
        } as? [String: AnySendable]

        return response?["data"]
    }

    func update(_ context: Context, value: Context.Value) throws {
        try updateIntoResult(context, value: value)
    }
}
