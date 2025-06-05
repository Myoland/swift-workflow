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


enum LLMProvider: Hashable, Codable {
    case OpenAI(OpenAIConfiguration)
    case OpenAICompatible(OpenAICompatibleConfiguration)
    // case AwsBedrock
    case Gemini
    case Dify(DifyConfiguration)
}

protocol LLMProviderSolver {
    func resolve(modelName: String) -> LLMProvider?
}

///
/// Example:
/// ```Yaml
/// id: "55442629-466e-4016-b45f-3fde51da0d6b"
/// name: Dify Ping Pong Bot
/// modelName: Gemini-Free-Text-Model
/// reponse: output
/// request:
///   input:
///     - lang
///     - to
///   query: "Call me {{ user_name }}. Hello!"
///   user: "{{ user_id }}"
/// ```
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
            let llmProvider = llmSolver.resolve(modelName: modelName)
        else {
            return .none
        }
        
        switch llmProvider {
        case .OpenAI(let configuration):
            let client = OpenAIClient(httpClient: client, configuration: configuration)
            
            let values = try request.render(context.filter(keys: nil))
            
            let request: OpenAIModelReponseRequest = try AnyDecoder().decode(from: values)
            let response = try await client.send(request: request)
            
            let contentLength: Int = if let header = response.headers[HTTPField.Name.contentLength.rawName].first,
                                        let length = Int(header) {
                length
            } else {
                .max
            }
            
            guard response.status == .ok else {
                var buffer = try? await response.body.collect(upTo: .max)
                let msg = buffer?.readString(length: contentLength, encoding: .utf8)
                todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
            }
            
            guard let contentType = response.headers[HTTPField.Name.contentType.rawName].first,
                  contentType.starts(with: ServerSentEvent.MIME_String)
            else {
                
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
        case .OpenAICompatible(let configuration):
            let client = OpenAICompatibleClient(httpClient: client, configuration: configuration)
            
            let values = try request.render(context.filter(keys: nil))
            let request: OpenAIChatCompletionRequest = try AnyDecoder().decode(from: values)
            let response = try await client.send(request: request)
            
            let contentLength: Int = if let header = response.headers[HTTPField.Name.contentLength.rawName].first,
                                        let length = Int(header) {
                length
            } else {
                .max
            }
            
            guard response.status == .ok else {
                var buffer = try? await response.body.collect(upTo: .max)
                let msg = buffer?.readString(length: contentLength, encoding: .utf8)
                todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
            }
            
            guard let contentType = response.headers[HTTPField.Name.contentType.rawName].first,
                  contentType.starts(with: ServerSentEvent.MIME_String)
            else {
                
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
        case .Gemini:
            todo("Support Gemini")
        case .Dify(let difyConfiguration):
            
            let decoder = AnyDecoder()
            let values = try request.render(context.filter(keys: nil))
            let body: DifyBody = try decoder.decode(from: values)
            
            let difyClient = DifyClient(httpClient: client, cfg: difyConfiguration)
            let response = try await difyClient.send(body: body)
            
            let contentLength: Int = if let header = response.headers[HTTPField.Name.contentLength.rawName].first,
               let length = Int(header) {
                length
            } else {
                .max
            }
            
            guard response.status == .ok else {
                var buffer = try? await response.body.collect(upTo: .max)
                let msg = buffer?.readString(length: contentLength, encoding: .utf8)
                todo("throw Node Runtime Error. Msg: \(msg ?? "nil")")
            }
            
            guard let contentType = response.headers[HTTPField.Name.contentType.rawName].first,
                  contentType.starts(with: ServerSentEvent.MIME_String)
            else {
                // BLOCKING
                var buffer = try? await response.body.collect(upTo: .max)
                let msg = buffer?.readString(length: contentLength) ?? ""
                return .block(msg)
            }
            
            // TODO: Convert to Custom Model Type, For now just Data.
            let stream = response.body.map { buffer in
                Foundation.Data.init(buffer: buffer)
            }
            
            let interpreter = AsyncServerSentEventsInterpreter(stream: .init(stream))
            
            return .stream(.init(interpreter.map({
                $0.data as AnySendable
            })))
        }
        
        unreachable()
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
