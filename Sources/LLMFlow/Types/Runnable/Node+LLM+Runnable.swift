//
//  Node+LLM+Runnable.swift
//  swift-workflow
//
//  Created by AFuture on 2025-08-23.
//

import LazyKit
import OpenAPIRuntime
import GPT
import SynchronizationKit

public protocol LLMProviderSolver {
    func resolve(modelName: String) -> LLMQualifiedModel?
}

public protocol GPTConversationCache: Sendable {
    func get(conversationID: String?) -> Conversation?
    func update(conversationID: String?, conversation: Conversation?)
}

extension LLMNode: Runnable {
    typealias Err = RuntimeError
    
    public func run(executor: Executor) async throws -> NodeOutput? {
        guard let locator = executor.locator else {
            throw Err.locatorNotFound
        }
        
        guard let client = locator.resolve(shared: ClientTransport.self) else {
            throw Err.serviceNotFound(name: "ClientTransport")
        }
        
        guard let llmSolver = locator.resolve(shared: LLMProviderSolver.self) else {
            throw Err.serviceNotFound(name: "LLMProviderSolver")
        }
        
        guard let llm = llmSolver.resolve(modelName: modelName) else {
            throw Err.unknow(message: "Throw error for miss LLMModel name '\(modelName)'")
        }
        
        let conversationCache = locator.resolve(shared: GPTConversationCache.self)

        let context = executor.context
        
        let inputs = context.filter(keys: nil) // TODO: only get necessary values
        let renderedValues = try request.render(inputs)
        let prompt: Prompt = try AnyDecoder().decode(from: renderedValues)
        executor.logger.info("[*] LLMNode(\(id)) Prompt: \(String(describing: prompt))")

        let conversationID = prompt.conversationID
        let conversation = conversationCache?.get(conversationID: conversationID)
        let session = GPTSession(client: client, conversation: conversation, logger: executor.logger)

        if prompt.stream == true {
            let response = try await session.stream(prompt, model: llm)
            
            // TODO: optimize the lifecyele.
            let iter = response.makeAsyncIterator()
            let output = AsyncThrowingStream(unfolding: { [iter] in
                var iter = iter
                if let next = try await iter.next() {
                    return try AnyEncoder().encode(next) as AnySendable
                } else {
                    conversationCache?.update(conversationID: conversationID, conversation: session.conversation)
                    return nil
                }
            })
            return .stream(output.cached().eraseToAnyAsyncSequence())
        } else {
            let response = try await session.generate(prompt, model: llm)
            let output = try AnyEncoder().encode(response)
            
            conversationCache?.update(conversationID: conversationID, conversation: session.conversation)
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
    
    public func update(_ context: Context, value: Context.Value) throws {
        context[path: resultKeyPaths] = value
        context[path: outputKeyPaths] = value
    }
}
