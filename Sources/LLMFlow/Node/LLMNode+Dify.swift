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
import LazyKit

struct DifyConfiguration: Hashable, Codable, Sendable {
    let apiKey: String
    let apiURL: String
}

struct DifyBody: Codable {
    let inputs: [String: String]
    let query: String
    let response_mode: String
    let conversation_id: String?
    let user: String?
    let files: [String]?
}

extension DifyBody {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        guard let query = try container.decodeIfPresent(String.self, forKey: .query) else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.query], debugDescription: "Missing Query"))
        }

        guard let user = try container.decodeIfPresent(String.self, forKey: .user) else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.user], debugDescription: "Missing User"))
        }
        
        let inputs = try container.decodeIfPresent([String: String].self, forKey: .inputs)
        let conversation_id = try container.decodeIfPresent(String.self, forKey: .conversation_id)
        let files = try container.decodeIfPresent([String].self, forKey: .files)
        
        self.inputs = inputs ?? [:]
        self.query = query
        self.response_mode = "streaming"
        self.conversation_id = conversation_id
        self.user = user
        self.files = files
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
