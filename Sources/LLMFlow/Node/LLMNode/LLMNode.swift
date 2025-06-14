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


public enum LLMProviderType: Hashable, Codable, Sendable {
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
    public let models: [LLMQualifiedModel]

    public init(name: String, models: [LLMQualifiedModel]) {
        self.name = name
        self.models = models
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
    func run(context: Context, pipe: OutputPipe) async throws -> OutputPipe {
        guard let locator = context.locator,
            let client = locator.resolve(shared: HttpClientAbstract.self),
            let llmSolver = locator.resolve(shared: LLMProviderSolver.self),
            let llm = llmSolver.resolve(modelName: modelName)
        else {
            return .none
        }

        let inputs = context.filter(keys: nil)

        for qualifiedModel in llm.models {
            var temp = inputs
            // TODO: using other prefix
            temp[path: "inputs", "model"] = qualifiedModel.name
            // let temp = inputs.merging(["inputs": ["model": qualifiedModel.name]]) { lhs, rhs in lhs }

            // [2025/06/08 <Huanan>] TODO: Catch Error and retry.
            switch qualifiedModel.provider.type {
            case .OpenAI:
                return try await preformOpenAIRequest(client: client, qualifiedModel: qualifiedModel, inputs: temp)
            case .OpenAICompatible:
                return try await preformOpenAICompatibleRequest(client: client, qualifiedModel: qualifiedModel, inputs: temp)
            case .Gemini:
                todo("Support Gemini. For now, Please use OpenAI Compatible.")
            }
        }

        unreachable()
    }

    func preformOpenAIRequest(client: HttpClientAbstract, qualifiedModel: LLMQualifiedModel, inputs: [String: AnySendable]) async throws -> OutputPipe {
        let client = OpenAIClient(httpClient: client, configuration: .init(apiKey: qualifiedModel.provider.apiKey, apiURL: qualifiedModel.provider.apiURL))

        let values = try request.render(inputs)
        let request: OpenAIModelReponseRequest = try AnyDecoder().decode(from: values)
        let response = try await client.send(request: request)

        let contentLength = response.contentLength ?? .max

        guard response.status == .ok else {
            var buffer = try? await response.body.collect(upTo: .max)
            let msg = buffer?.readString(length: contentLength, encoding: .utf8)
            todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
        }

        guard response.contentType == ServerSentEvent.MIME_String else {

            let data = try await response.body.collect(upTo: .max)
            let decoder = JSONDecoder()
            let result = try decoder.decode(OpenAIModelReponse.self, from: data)

            return .block(result)
        }


        let decoder = JSONDecoder()

        let stream = response.body.map { buffer in
            Foundation.Data.init(buffer: buffer)
        }

        let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))

        return .stream(.init(interpreter.map {
            guard let data = $0.data.data(using: .utf8) else {
                todo("Throw Error")
            }

            return try decoder.decode(OpenAIModelStreamResponse.self, from: data) as AnySendable
        }))
    }

    func preformOpenAICompatibleRequest(client: HttpClientAbstract, qualifiedModel: LLMQualifiedModel, inputs: [String: AnySendable]) async throws -> OutputPipe {
        let client = OpenAICompatibleClient(httpClient: client, configuration: .init(apiKey: qualifiedModel.provider.apiKey, apiURL: qualifiedModel.provider.apiURL))

        let values = try request.render(inputs)
        let request: OpenAIChatCompletionRequest = try AnyDecoder().decode(from: values)
        let response = try await client.send(request: request)

        let contentLength = response.contentLength ?? .max

        guard response.status == .ok else {
            var buffer = try? await response.body.collect(upTo: .max)
            let msg = buffer?.readString(length: contentLength, encoding: .utf8)
            todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
        }

        guard response.contentType == ServerSentEvent.MIME_String else {

            let data = try await response.body.collect(upTo: .max)
            let decoder = JSONDecoder()
            let result = try decoder.decode(OpenAIChatCompletionResponse.self, from: data)
            return .block(result)
        }

        let decoder = JSONDecoder()

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

            return try decoder.decode(OpenAIChatCompletionStreamResponse.self, from: data) as AnySendable
        }))
    }
}

extension LLMNode {
    public func wait(_ pipe: OutputPipe) async throws -> Context.Value? {
        if case .none = pipe {
            return nil
        }

        if case let .block(value) = pipe {
            return value
        }

        guard case .stream(let stream) = pipe else {
            return nil
        }

        return try await Array(stream)
    }
}
