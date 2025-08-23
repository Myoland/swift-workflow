//
//  Node+LLM+Runnable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//

import LazyKit
import OpenAPIRuntime
import GPT

public protocol LLMProviderSolver {
    func resolve(modelName: String) -> LLMQualifiedModel?
}

extension LLMNode: Runnable {
    
    public func run(executor: Executor) async throws -> NodeOutput? {
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
        
        let session = GPTSession(client: client, logger: executor.logger)
        
        if prompt.stream == true {
            let response = try await session.stream(prompt, model: llm)
            let output = response.map { response in
                return try AnyEncoder().encode(response)
            }.cached().eraseToAnyAsyncSequence()
            
            return .stream(output)
        } else {
            let response = try await session.generate(prompt, model: llm)
            let output = try AnyEncoder().encode(response)
            
            return .block(output)
        }
    }
}

extension LLMNode {
    public func wait(_ context: Context) async throws -> Context.Value? {
        let output = context.payload.withLock { $0 }
        
        guard let stream = output?.stream else {
            return output?.value
        }
        
        let response = try await stream.first { value in
            let response = value as? [String: AnySendable]
            let event = response?["event"] as? String
            return event == ModelStreamResponse.EventName.completed.rawValue
        } as? [String: AnySendable]
        
        return response?["data"]
    }
    
    func update(_ context: Context, value: Context.Value) throws {
        context[path: resultKeyPaths] = value
        context[path: outputKeyPaths] = value
    }
}
