//
//  Node+LLM.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/24.
//
//
//
import AsyncHTTPClient
import Foundation
import HTTPTypes
import NIOFoundationCompat
import NIOHTTP1
import LazyKit
import AsyncAlgorithms
import OSLog


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
            let client = locator.resolve(shared: HttpClientAbstract.self),
            let llmSolver = locator.resolve(shared: LLMProviderSolver.self),
            let llm = llmSolver.resolve(modelName: modelName)
        else {
            executor.logger.error("[*] LLMModel Not Matched For '\(modelName)'")
            todo("Throw error for miss LLMModel")
        }

        let context = executor.context
        let inputs = context.filter(keys: nil)

        let models = llm.models.filter({ $0.provider.type == llm.type })
        let output = switch llm.type {
            case .OpenAI:
                try await performOpenAIRequet(client: client, models: models, inputs: inputs, logger: executor.logger)
            case .OpenAICompatible:
                try await performOpenAICompatibleRequet(client: client, models: models, inputs: inputs, logger: executor.logger)
            default:
                todo("Throw error that llm model is not supported")
        }
        context.output.withLock { $0 = output }
    }
}

extension LLMNode {
    func performOpenAIRequet(
        client: HttpClientAbstract,
        models: [LLMQualifiedModel],
        inputs:  Context.Store,
        logger: Logger
    ) async throws -> NodeOutput {
        assert(Set(models.map(\.provider.type)).count == 1, "Multiple providers type are not supported")

        for model in models {
            var temp = inputs
            // TODO: using other prefix
            temp[path: "inputs", "model"] = model.name

            let values = try request.render(temp)
            logger.debug("[*] LLM Node. rcequests rendered.\n\(values)")

            let request: OpenAIModelReponseRequest = try AnyDecoder().decode(from: values)

            do {
                return try await preformOpenAIRequest(client: client, qualifiedModel: model, request: request)
            } catch {
                logger.error("[*] LLM Node. request failed.\n\(error)")
                throw error
            }
        }

        logger.error("[*] LLM Node. all requests failed.")
        todo("Throw error for all provider failed")
    }

    func performOpenAICompatibleRequet(
        client: HttpClientAbstract,
        models: [LLMQualifiedModel],
        inputs:  Context.Store,
        logger: Logger
    ) async throws -> NodeOutput {
        assert(Set(models.map(\.provider.type)).count == 1, "Multiple providers type are not supported")

        for model in models {
            var temp = inputs
            // TODO: using other prefix
            temp[path: "inputs", "model"] = model.name

            let values = try request.render(temp)
            logger.debug("[*] LLM Node. rcequests rendered.\n\(values)")

            let request: OpenAIChatCompletionRequest = try AnyDecoder().decode(from: values)

            do {
                return try await preformOpenAICompatibleRequest(client: client, qualifiedModel: model, request: request)
            } catch {
                logger.error("[*] LLM Node. all requests failed.")
                throw error
            }
        }

        logger.error("[*] LLM Node. all requests failed.")
        todo("Throw error for all provider failed")
    }
}

extension LLMNode {

    func preformOpenAIRequest(client: HttpClientAbstract, qualifiedModel: LLMQualifiedModel, request: OpenAIModelReponseRequest) async throws -> NodeOutput {
        let client = OpenAIClient(httpClient: client, configuration: .init(apiKey: qualifiedModel.provider.apiKey, apiURL: qualifiedModel.provider.apiURL))

        let response = try await client.send(request: request)

        guard response.status == .ok else {
            var buffer = try? await response.body.collect(upTo: .max)
            let contentLength = response.contentLength ?? .max
            let msg = buffer?.readString(length: contentLength, encoding: .utf8)
            todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
        }

        let jsonDecoder = JSONDecoder()

        guard let contentType = response.contentType, contentType.starts(with: ServerSentEvent.MIME_String) else {

            let data = try await response.body.collect(upTo: .max)
            let result = try jsonDecoder.decode(OpenAIModelReponse.self, from: data)

            return .block(result)
        }

        let stream = response.body.map { buffer in
            Foundation.Data.init(buffer: buffer)
        }

        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))

        return .stream(.init(interpreter.map {
            guard let data = $0.data.data(using: .utf8) else {
                todo("Throw Error")
            }
            return try jsonDecoder.decode(OpenAIModelStreamResponse.self, from: data)
        }.map { (res: OpenAIModelStreamResponse) in
            return try AnyEncoder().encode(res)
        }.cached()))
    }

    func preformOpenAICompatibleRequest(client: HttpClientAbstract, qualifiedModel: LLMQualifiedModel, request: OpenAIChatCompletionRequest) async throws -> NodeOutput {
        let client = OpenAICompatibleClient(httpClient: client, configuration: .init(apiKey: qualifiedModel.provider.apiKey, apiURL: qualifiedModel.provider.apiURL))

        let response = try await client.send(request: request)

        guard response.status == .ok else {
            var buffer = try? await response.body.collect(upTo: .max)
            let contentLength = response.contentLength ?? .max
            let msg = buffer?.readString(length: contentLength, encoding: .utf8)
            todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
        }

        let jsonDecoder = JSONDecoder()

        guard let contentType = response.contentType, contentType.starts(with: ServerSentEvent.MIME_String) else {

            let data = try await response.body.collect(upTo: .max)
            let result = try jsonDecoder.decode(OpenAIChatCompletionResponse.self, from: data)
            return .block(result)
        }

        let stream = response.body.map { buffer in
            Foundation.Data.init(buffer: buffer)
        }

        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))

        return try .stream(.init(interpreter.prefix {
            $0.data != "[DONE]"
        }.map {
            guard let data = $0.data.data(using: .utf8) else {
                todo("Throw Error")
            }

            return try jsonDecoder.decode(OpenAIChatCompletionStreamResponse.self, from: data)
        }.map { (res: OpenAIChatCompletionStreamResponse) in
            return try AnyEncoder().encode(res)
        }.cached()))
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
