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

@Test("testStoreSimpleRead")
func testStoreSimpleRead() async throws {
    do {
        let store: [String: AnySendable] = ["foo": "bar"]
        #expect(store["foo"] as? String == "bar")
    }

    do {
        let store: [AnySendable] = ["foo", "bar"]

        #expect(store[key: .init(intValue: 0)] as? String == "foo")
        #expect(store[key: .init(intValue: 1)] as? String == "bar")
    }
}

@Test("testStoreNestRead")
func testStoreNestRead() async throws {
    do {
        let store: [String: AnySendable] = ["foo": ["bar": "baz"]]
        #expect(store[path: ["foo", "bar"]] as? String == "baz")
    }

    do {
        let store: [AnySendable] = [["foo", "bar"], ["baz", "raz"]]
        #expect(store[path: [0, 0]] as? String == "foo")
        #expect(store[path: [0, 1]] as? String == "bar")
        #expect(store[path: [1, 0]] as? String == "baz")
        #expect(store[path: [1, 1]] as? String == "raz")
    }

    do {
        let store: [String: AnySendable] = ["foo": ["bar", "baz"]]
        #expect(store[path: ["foo"]] as? [String]? == ["bar", "baz"])
        #expect(store[path: ["foo", 0]] as? String == "bar")
        #expect(store[path: ["foo", 1]] as? String == "baz")
    }

    do {
        let store: [AnySendable] = [["foo": "bar"], ["baz": "raz"]]
        #expect(store[path: [0]] as? [String: String]? == ["foo": "bar"])
        #expect(store[path: [1]] as? [String: String]? == ["baz": "raz"])
        #expect(store[path: [0, "foo"]] as? String == "bar")
        #expect(store[path: [1, "baz"]] as? String == "raz")
    }
}

@Test("testStoreSimpleModify")
func testStoreSimpleModify() async throws {
    do {
        var store: [String: AnySendable] = ["foo": "bar"]
        store["foo"] = "baz"

        #expect(store["foo"] as? String != "bar")
        #expect(store["foo"] as? String == "baz")
    }

    do {
        var store: [AnySendable] = ["foo", "bar"]
        store[0] = "baz"

        #expect(store[key: .init(intValue: 0)] as? String != "foo")
        #expect(store[key: .init(intValue: 0)] as? String == "baz")
        #expect(store[key: .init(intValue: 1)] as? String == "bar")
    }
}

@Test("testStoreModify")
func testStoreModify() async throws {
    do {
        var store: [String: AnySendable] = ["foo": ["bar": "baz"]]
        store["foo"] = "value 1"

        #expect(store["foo"] as? String == "value 1")
    }

    do {
        var store: [String: AnySendable] = ["foo": ["bar": "baz"]]
        store[path: ["foo", "bar"]] = "value 1"

        #expect(store[path: ["foo", "bar"]] as? String == "value 1")
    }

    do {
        var store: [AnySendable] = [["foo", "bar"], ["baz", "raz"]]
        store[path: [0]] = "value 1"

        #expect(store[path: [0]] as? String == "value 1")
        #expect(store[path: [1]] as? [String]? == ["baz", "raz"])
    }

    do {
        var store: [AnySendable] = [["foo": "bar"], ["baz": "raz"]]
        store[path: [0]] = "value 1"

        #expect(store[path: [0]] as? String == "value 1")
        #expect(store[path: [1]] as? [String: String]? == ["baz": "raz"])
    }

    do {
        var store: [AnySendable] = [["foo": "bar"], ["baz": "raz"]]
        store[path: [0, "foo"]] = "value 1"

        #expect(store[path: [0]] as? [String: String]? == ["foo": "value 1"])
        #expect(store[path: [0, "foo"]] as? String == "value 1")
        #expect(store[path: [1]] as? [String: String]? == ["baz": "raz"])
    }

    do {
        var store: [String: AnySendable] = ["foo": ["bar", "baz"]]
        store[path: ["foo", 0]] = "value 1"

        #expect(store[path: ["foo"]] as? [String]? == ["value 1", "baz"])
        #expect(store[path: ["foo", 0]] as? String == "value 1")
    }
}
