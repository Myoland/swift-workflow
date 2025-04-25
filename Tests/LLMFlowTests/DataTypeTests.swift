//
//  DataTypeTests.swift
//  dify-forward
//
//  Created by AFuture on 2025/3/1.
//

import Foundation
import Testing
import Yams

@testable import LLMFlow

@Test(
    "testEnecodeDataTypeSingle",
    arguments: [
        (
            1 as FlowData.Single,
            "1\n"
        ),
        (
            "foo",
            "foo\n"
        ),
    ])
func testEnecodeDataTypeSingle(_ value: FlowData.Single, expect: String) throws {
    let encoder = YAMLEncoder()
    let encoded = try encoder.encode(value)
    #expect(encoded == expect)
}

@Test(
    "testDecodeDataTypeSingle",
    arguments: [
        1 as FlowData.Single,
        "foo",
    ])
func testDecodeDataTypeSingle(_ value: FlowData.Single) async throws {
    let encoder = YAMLEncoder()
    let decoder = YAMLDecoder()

    let encoded = try encoder.encode(value)
    let decoded = try decoder.decode(FlowData.Single.self, from: encoded)
    #expect(value == decoded)
}

@Test(
    "testEnecodeDataTypeList",
    arguments: [
        (
            [] as FlowData.List,
            "[]"
        ),
        (
            [1, "2"] as FlowData.List,
            """
            - 1
            - '2'
            """
        ),
        (
            [
                [],
                [1, "2"],
            ] as FlowData.List,
            """
            - []
            - - 1
              - '2'
            """
        ),
        (
            [
                [:],
                [
                    "foo": 1,
                    "bar": "2",
                ],
            ] as FlowData.List,
            """
            - {}
            - bar: '2'
              foo: 1
            """
        ),
    ])
func testEnecodeDataTypeList(_ value: FlowData.List, expect: String) throws {
    let encoder = YAMLEncoder()
    encoder.options.sortKeys = true
    let encoded = try encoder.encode(value)
    #expect(encoded.trimmingCharacters(in: .whitespacesAndNewlines) == expect)
}

@Test(
    "testEncodeDataTypeMap",
    arguments: [
        (
            [:] as FlowData.Map,
            "{}"
        ),
        (
            [
                "foo": 1,
                "bar": "2",
            ] as FlowData.Map,
            "bar: '2'\nfoo: 1"
        ),
        (
            [
                "foo": [],
                "bar": [1, "2"],
            ] as FlowData.Map,
            """
            bar:
            - 1
            - '2'
            foo: []
            """
        ),
        (
            [
                "foo": [:],
                "bar": [
                    "baz": 1,
                    "qux": "2",
                ],
            ] as FlowData.Map,
            """
            bar:
              baz: 1
              qux: '2'
            foo: {}
            """
        ),
    ])
func testEncodeDataTypeMap(_ value: FlowData.Map, expect: String) throws {
    let encoder = YAMLEncoder()
    encoder.options.sortKeys = true
    let encoded = try encoder.encode(value)
    #expect(encoded.trimmingCharacters(in: .whitespacesAndNewlines) == expect)
}

@Test(
    "testDecodeDataTypeMap",
    arguments: [
        [:] as FlowData.Map,
        [
            "foo": 1,
            "bar": "2",
        ] as FlowData.Map,
        [
            "foo": [],
            "bar": [1, "2"],
        ] as FlowData.Map,
        [
            "foo": [:],
            "bar": [
                "baz": 1,
                "qux": "2",
            ],
        ] as FlowData.Map,
    ])
func testDecodeDataTypeMap(_ value: FlowData.Map) async throws {
    let encoder = YAMLEncoder()
    let decoder = YAMLDecoder()

    let encoded = try encoder.encode(value)
    let decoded = try decoder.decode(FlowData.Map.self, from: encoded)

    #expect(value == decoded)
}
