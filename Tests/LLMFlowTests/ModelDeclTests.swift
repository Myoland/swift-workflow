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
    let decl = ModelDecl([
        "$model": ["params", "model"],
        "stream": true,
        "input": [[
            "role": "system",
            "content": [[
                "type": "input_text",
                "text": """
                    be an echo server.
                    before response, say 'hi [USER NAME]' first.
                    what I send to you, you send back.
                
                    the exceptions:
                    1. send "ping", back "pong"
                    2. send "ding", back "dang"
                """
            ]]
        ], [
            "role": "system",
            "content": [[
                "type": "input_text",
                "#text": "you are talking to {{params.name}}"
            ]]
        ], [
            "role": "user",
            "content": [[
                "type": "input_text",
                "$text": ["params", "message"]
            ]]
        ]],
    ])
    
    let store: [String: Any] = [
        "sender": "swift",
        "params": [
            "name": "John",
            "model": "gpt-4o-mini",
            "message": "ping"
        ]
    ]
    
    let result = try decl.render(store)
    
    #expect(result["model"] as? String == "gpt-4o-mini")
    #expect(result["stream"] as? Bool == true)
    
    let input = result["input"] as! [[String: Any]]
    
    #expect((input[0]["content"] as! [[String: String]])[0]["text"] == """
        be an echo server.
        before response, say 'hi [USER NAME]' first.
        what I send to you, you send back.
    
        the exceptions:
        1. send "ping", back "pong"
        2. send "ding", back "dang"
    """)
    #expect((input[1]["content"] as! [[String: String]])[0]["text"] == "you are talking to John")
    #expect((input[2]["content"] as! [[String: String]])[0]["text"] == "ping")
}
