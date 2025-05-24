//
//  WorkflowTests.swift
//  dify-forward
//
//  Created by Huanan on 2025/2/20.
//
@testable import LLMFlow

import Testing
import Foundation
import Yams

@Test("testEncodeCondition", arguments: [
    (
        Condition.string(.empty(variable: "var 1")),
        """
        empty:
          variable: var 1
        """
    ),
    (
        Condition.string(.equal(variable: "var 2", value: "foo")),
        """
        equal:
          variable: var 2
          value: foo
        """
    ), (
        Condition.string(.contains(variable: "var 3", value: "bar", position: .default)),
        """
        contains:
          variable: var 3
          value: bar
          position: default
        """
    ), (
        Condition.string(.contains(variable: "var 4", value: "baz", position: .suffix)),
        """
        contains:
          variable: var 4
          value: baz
          position: suffix
        """
    ), (
        Condition.int(.equal(variable: "var 5", value: 1)),
        """
        equal:
          variable: var 5
          value: 1
        """
    ), (
        Condition.int(.greater(variable: "var 6", value: 2)),
        """
        greater:
          variable: var 6
          value: 2
        """
    ), (
        Condition.int(.greater_or_equal(variable: "var 7", value: 3)),
        """
        greater_or_equal:
          variable: var 7
          value: 3
        """
    ), (
        Condition.int(.smaller(variable: "var 8", value: 4)),
        """
        smaller:
          variable: var 8
          value: 4
        """
    ), (
        Condition.int(.smaller_or_equal(variable: "var 9", value: 5)),
        """
        smaller_or_equal:
          variable: var 9
          value: 5
        """
    ), (
        Condition.not(.string(.empty(variable: "var 10"))),
        """
        not:
          empty:
            variable: var 10
        """
    ), (
        Condition.and([
            .string(.empty(variable: "var 11")),
            .string(.equal(variable: "var 12", value: "12"))
        ]),
        """
        and:
        - empty:
            variable: var 11
        - equal:
            variable: var 12
            value: '12'
        """
    ), (
        Condition.or([
            .int(.equal(variable: "var 13", value: 13)),
            .string(.equal(variable: "var 14", value: "14")),
            .not(.string(.empty(variable: "var 15")))
        ]),
        """
        or:
        - equal:
            variable: var 13
            value: 13
        - equal:
            variable: var 14
            value: '14'
        - not:
            empty:
              variable: var 15
        """
    )
])
func testEncodeConditionOP(_ op: Condition, expect: String) throws {
    let encoder = YAMLEncoder()
    let encoded = try encoder.encode(op)
    #expect(encoded.trimmingCharacters(in: .whitespacesAndNewlines) == expect)
}



@Test("testDecodeCondition", arguments: [
    Condition.string(.empty(variable: "var 1")),
    Condition.string(.equal(variable: "var 2", value: "foo")),
    Condition.string(.contains(variable: "var 3", value: "bar", position: .default)),
    Condition.string(.contains(variable: "var 4", value: "baz", position: .suffix)),
    Condition.int(.equal(variable: "var 5", value: 1)),
    Condition.int(.greater(variable: "var 6", value: 2)),
    Condition.int(.greater_or_equal(variable: "var 7", value: 3)),
    Condition.int(.smaller(variable: "var 8", value: 4)),
    Condition.int(.smaller_or_equal(variable: "var 9", value: 5)),
    Condition.not(.string(.empty(variable: "var 10"))),
    Condition.and([
        .string(.empty(variable: "var 11")),
        .string(.equal(variable: "var 12", value: "12"))
    ]),
    Condition.or([
        .int(.equal(variable: "var 13", value: 13)),
        .string(.equal(variable: "var 14", value: "14")),
        .not(.string(.empty(variable: "var 15")))
    ]),
])
func testDecodeConditionOP(_ op: Condition) throws {
    let encoder = YAMLEncoder()
    let decoder = YAMLDecoder()
    
    let encoded = try encoder.encode(op)
    let decoded = try decoder.decode(Condition.self, from: encoded)
    #expect(op == decoded)
}

@Test("testConditionTrue", arguments: [
    (Condition.string(.empty(variable: "var 1")), true),
    (Condition.string(.equal(variable: "var 2", value: "foo")), true),
    (Condition.string(.contains(variable: "var 3", value: "bar", position: .default)), true),
    (Condition.string(.contains(variable: "var 4", value: "baz", position: .suffix)), true),
    (Condition.int(.equal(variable: "var 5", value: 1)), true),
    (Condition.int(.greater(variable: "var 6", value: 2)), true),
    (Condition.int(.greater_or_equal(variable: "var 7", value: 3)), true),
    (Condition.int(.smaller(variable: "var 8", value: 4)), true),
    (Condition.int(.smaller_or_equal(variable: "var 9", value: 5)), true),
    (Condition.not(.string(.empty(variable: "var 10"))), true),
    (Condition.and([
        .string(.empty(variable: "var 11")),
        .string(.equal(variable: "var 12", value: "12"))
    ]), true),
    (Condition.or([
        .int(.equal(variable: "var 13", value: 13)),
        .string(.equal(variable: "var 14", value: "14")),
        .not(.string(.empty(variable: "var 15")))
    ]), true),
])
func testConditionTrue(_ op: Condition, expect: Bool) {
    let inputs: [String: FlowData] = [
        "var 1": "",
        "var 2": "foo",
        "var 3": "xxbarxx",
        "var 4": "xxbaz",
        "var 5": 1,
        "var 6": 3,
        "var 7": 4,
        "var 8": 3,
        "var 9": 3,
        "var 10": "10",
        "var 11": "",
        "var 12": "12",
        "var 13": "13",
        "var 14": "14",
        "var 15": "15",
    ]
    
    
    let result = op.eval(inputs)
    #expect(result == expect)
}
