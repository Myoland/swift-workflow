//
//  LLMNode+OpenAI.swift
//  dify-forward
//
//  Created by AFuture on 2025/4/9.
//

import LazyKit
import HTTPTypes
import Foundation
import NIOHTTP1

struct OpenAIConfiguration: Hashable, Codable, Sendable {
    let apiKey: String
    let apiURL: String
}

struct OpenAIClient {
    let httpClient: any HttpClientAbstract
    let configuration: OpenAIConfiguration

    init(httpClient: any HttpClientAbstract, configuration: OpenAIConfiguration) {
        self.httpClient = httpClient
        self.configuration = configuration
    }

    func send(request: OpenAIModelReponseRequest) async throws -> HttpClientAbstract.Response {

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(configuration.apiKey)",
        ]

        let request = try {
            var req = HttpClientAbstract.Request(url: "\(configuration.apiURL)/v1/responses")
            req.method = .POST
            req.headers = headers
            req.body = .bytes(try JSONEncoder().encodeAsByteBuffer(request, allocator: .init()))
            return req
        }()

        return try await httpClient.send(request: request)
    }
}
