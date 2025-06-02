//
//  StoreTests.swift
//  swift-workflow
//
//  Created by AFuture on 2025/6/2.
//

import Foundation
import Testing
import TestKit

@testable import LLMFlow


@Test("testStoreRead")
func testStoreRead() async throws {
    do {
        let store: [String: Any] = ["foo": "bar"]
        #expect(store["foo"] as? String == "bar")
    }
    
    do {
        let store: [String: Any] = ["foo": ["bar": "baz"]]
        #expect(store[path: ["foo", "bar"]] as? String == "baz")
    }
    
    do {
        var store: [String: Any] = ["foo": "bar"]
        store["foo"] = "baz"
        
        #expect(store["foo"] as? String != "bar")
        #expect(store["foo"] as? String == "baz")
    }
    
    do {
        var store: [String: Any] = ["foo": ["bar": "baz"]]
        store["foo"] = "value 1"
        
        #expect(store["foo"] as? String == "value 1")
    }
    
    do {
        var store: [String: Any] = ["foo": ["bar": "baz"]]
        store[path: ["foo", "bar"]] = "value 1"
        print(store)
        
        #expect(store[path: ["foo", "bar"]] as? String == "value 1")
    }
    
}
