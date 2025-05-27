//
//  DataKeyPathTests.swift
//  swift-workflow
//
//  Created by AFuture on 2025/5/27.
//

import Testing
import Foundation

@testable import LLMFlow

@Test("testDataKeyPath")
func testDataKeyPath() async throws {
    let str = "{\"foo\":\"bar\"}"
    let decoder = JSONDecoder()
    
    let decoded = try decoder.decode([DataKeyPath: String].self, from: str.data(using: .utf8)!)
    print(decoded)
}
