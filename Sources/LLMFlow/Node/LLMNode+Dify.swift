//
//  LLMNode+Dify.swift
//  dify-forward
//
//  Created by AFuture on 2025/4/9.
//

import HTTPTypes
import AsyncHTTPClient
import Foundation
import NIOHTTP1
import WantLazy

struct DifyConfiguration: Hashable, Codable, Sendable {
    let apiKey: String
    let apiURL: String
}

struct DifyBody: Codable {
    let inputs: [String: String]
    let query: String
    let response_mode: String
    let conversation_id: String
    let user: String
    let files: [String]
}

extension DifyBody {
    init(request: [String: FlowData], store: [String: FlowData]) throws {
        
        let inputKeys = request["inputs"]?.asAny as? [String]
        let conversationIdKey = request["conversation_id"]?.stringValue
        let userIdKey = request["user"]?.stringValue
        
        let input = store.extract(inputKeys).compactMapValuesAsString()
        
        let queryTemplate = Template(content: request["query"]?.stringValue ?? "")
        let query = try queryTemplate.render(store)
        
        
        self.init(
            inputs: input,
            query: query,
            response_mode: "streaming",
            conversation_id: store[conversationIdKey]?.stringValue ?? "",
            user: store[userIdKey]?.stringValue ?? "",
            files: []
        )
    }
}

struct DifyClient {
    
    let httpClient: any HttpClientAbstract
    let cfg: DifyConfiguration
    
    init(httpClient: any HttpClientAbstract, cfg: DifyConfiguration) {
        self.httpClient = httpClient
        self.cfg = cfg
    }
    
    func send(body: DifyBody) async throws -> HttpClientAbstract.Response {
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(cfg.apiKey)",
        ]
        
        let request = try {
            var req = HttpClientAbstract.Request(url: "\(cfg.apiURL)/chat-messages")
            req.method = .POST
            req.headers = headers
            req.body = .bytes(try JSONEncoder().encodeAsByteBuffer(body, allocator: .init()))
            return req
        }()
        
        return try await httpClient.send(request: request)
    }
    
}
