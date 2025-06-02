//
//  ModelDeclTests.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/2.
//

import Foundation
import Testing
import TestKit

@testable import LLMFlow


@Test("testModelDecl")
func testModelDecl() async throws {
    let decl = ModelDecl(body: [
        "$name" : ["params", "name"],
        "type" : "person",
        "#message": """
        Hi {{sender}}:
        I'm {{params.name}}.
        """
    ])
    
    let store: [String: Any] = [
        "sender": "swift",
        "params": [
            "name": "John"
        ]
    ]
    
    let result = try decl.render(store)
    
    #expect(result["name"] as? String == "John")
    #expect(result["type"] as? String == "person")
    #expect(result["message"] as? String == "Hi swift:\nI\'m John.")
}
