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
import WantLazy


enum LLMProvider: Hashable, Codable {
    case OpenAI(OpenAIConfiguration)
    case OpenAICompatible(OpenAICompatibleConfiguration)
    case AwsBedrock
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

    let request: [String: FlowData]
    let response: NodeVariableKey

    init(
        id: ID,
        name: String?,
        modelName: String,
        request: [String: FlowData],
        response: NodeVariableKey
    ) {
        self.id = id
        self.name = name
        self.type = .LLM
        self.modelName = modelName
        self.request = request
        self.response = response
    }
}

extension LLMNode {
    func run(context: inout Context) async throws -> OutputPipe {
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
            
            let decoder = LazyDecoder()
            let keyes = request.compactMapValuesAsString()
            let values = context.filter(keys: nil).mapKeys(keys: keyes)  // TODO: allow extract values by CodingKeys.
            let request: OpenAIModelReponseRequest = try decoder.decode(from: values)
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
            
            let stream = response.body.map { buffer in
                Foundation.Data.init(buffer: buffer)
            }
            
            return .stream(.init(stream))
        case .OpenAICompatible(let configuration):
            let client = OpenAICompatibleClient(httpClient: client, configuration: configuration)
            
            let decoder = LazyDecoder()
            let keyes = request.compactMapValuesAsString()
            let values = context.filter(keys: nil).mapKeys(keys: keyes)  // TODO: allow extract values by CodingKeys.
            let request: OpenAIChatCompletionRequest = try decoder.decode(from: values)
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
                    
                print("[*]", result)
                
                return .block(key: self.response, value: result)
            }
            
            let stream = response.body.map { buffer in
                Foundation.Data.init(buffer: buffer)
            }
            
            return .stream(.init(stream))
        case .AwsBedrock:
            todo("Support AwsBedrock")
        case .Gemini:
            todo("Support Gemini")
        case .Dify(let difyConfiguration):
            
            let decoder = LazyDecoder()
            let keyes = request.compactMapValuesAsString()
            let values = context.filter(keys: nil).mapKeys(keys: keyes)  // TODO: allow extract values by CodingKeys.
            let body: DifyBody = try decoder.decode(from: values)
            
//             TODO: Support dispatch by `llmProvider`
//             let body: DifyBody = try .init(request: request, store: context.store)
            
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
                return .block(key: self.response, value: msg)
            }
            
            // TODO: Convert to Custom Model Type, For now just Data.
            let stream = response.body.map { buffer in
                Foundation.Data.init(buffer: buffer)
            }
            
            return .stream(.init(stream))
        }
        

        unreachable()
    }
}
