//
//  LLMNode+OpenAICompatible.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/20.
//

import WantLazy
import HTTPTypes
import Foundation
import NIOHTTP1

struct OpenAICompatibleConfiguration: Hashable, Codable, Sendable {
    let apiKey: String
    let apiURL: String
}

struct OpenAICompatibleClient {
    let httpClient: any HttpClientAbstract
    let configuration: OpenAICompatibleConfiguration
    
    init(httpClient: any HttpClientAbstract, configuration: OpenAICompatibleConfiguration) {
        self.httpClient = httpClient
        self.configuration = configuration
    }
    
    func send(request: OpenAIChatCompletionRequest) async throws -> HttpClientAbstract.Response {
        
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(configuration.apiKey)",
        ]
        
        let request = try {
            var req = HttpClientAbstract.Request(url: "\(configuration.apiURL)/v1/chat/completions")
            req.method = .POST
            req.headers = headers
            req.body = .bytes(try JSONEncoder().encodeAsByteBuffer(request, allocator: .init()))
            return req
        }()
        
        return try await httpClient.send(request: request)
    }
}
